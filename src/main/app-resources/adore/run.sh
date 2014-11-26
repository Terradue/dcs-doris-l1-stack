#!/bin/bash
 
# source the ciop functions (e.g. ciop-log)
source ${ciop_job_include}

# define the exit codes
SUCCESS=0
ERR_CURL=1
ERR_ADORE=2
ERR_PUBLISH=3
ERR_WRONGPROD=4

# add a trap to exit gracefully
function cleanExit ()
{
	local retval=$?
	local msg=""
	
	case "$retval" in
		$SUCCESS) msg="Processing successfully concluded";;
		$ERR_CURL) msg="Failed to retrieve the products";;
		$ERR_ADORE) msg="Failed during ADORE execution";;
		$ERR_PUBLISH) msg="Failed results publish";;
		$ERR_WRONGPROD) msg="Wrong product provided as input [`basename ${SLAVE}`]. Please use ASA_IMS_1P";;
		*) msg="Unknown error";;
	esac

	[ "$retval" != "0" ] && ciop-log "ERROR" "Error $retval - $msg, processing aborted" || ciop-log "INFO" "$msg"
	exit $retval
}
trap cleanExit EXIT

MASTER="`ciop-getparam adore_master`"
PROJECT="`ciop-getparam adore_project`"

#retrieving the slave
while read SLAVE
do
	ciop-log "INFO" "received the following input [${SLAVE}]"

	# path and master/slave variable definition
	UUID=`uuidgen`
	UUIDTMP="/tmp/${UUID}"

	# creates the adore directory structure
	ciop-log "INFO" "creating the directory structure [${UUIDTMP}]"

	ciop-log "INFO" "basedir is ${UUIDTMP}"

	# copies the ODR files
	[ ! -e /tmp/ODR ] && {
		ciop-log "INFO" "copying the ODR files"
		tar xvfz /application/adore/files/ODR.tgz -C /tmp &> /dev/null
	}

	# copies the master
	ciop-log "INFO" "downloading master [${MASTER}]"
	MASTER=`ciop-copy -f -O /tmp ${MASTER}`
	res=$?
	[ $res -ne 0 ] && exit $ERR_CURL

	# let's check if the correct product was provided
	[ "`head -10 ${MASTER} | grep "^PRODUCT" | tr -d '"' | cut -d "=" -f 2 | cut -c 1-10`" != "ASA_IMS_1P" ] && exit $ERR_WRONGPROD

	ciop-log "INFO" "downloading slave [${SLAVE}]"
	SLAVE=`ciop-copy -f -O /tmp ${SLAVE}`
	res=$?
	[ $res -ne 0 ] && exit $ERR_CURL

	# let's check if the correct product was provided
	[ "`head -10 ${SLAVE} | grep "^PRODUCT" | tr -d '"' | cut -d "=" -f 2 | cut -c 1-10`" != "ASA_IMS_1P" ] && exit $ERR_WRONGPROD

	SLAVE_ID=`head -10 ${SLAVE} | grep "^PRODUCT" | tr -d '"' | cut -d "=" -f 2 | cut -c 15-22`

	ciop-log "INFO" "creating dirs"
	mkdir -p ${UUIDTMP}
	mkdir ${UUIDTMP}/data
	mkdir ${UUIDTMP}/data/master
	mkdir ${UUIDTMP}/data/${SLAVE_ID}

	# moves the files to the correct places
	mv ${MASTER} ${UUIDTMP}/data/master/
	MASTER=${UUIDTMP}/data/master/`basename ${MASTER}`
	mv ${SLAVE} ${UUIDTMP}/data/${SLAVE_ID}/
	SLAVE=${UUIDTMP}/data/${SLAVE_ID}/`basename ${SLAVE}`

	# setting the adore settings.set file
	cat > ${UUIDTMP}/settings.set <<EOF
projectFolder="${UUIDTMP}"
runName="${PROJECT}"
master="master"
slave="${SLAVE_ID}"
scenes_include=( master ${SLAVE_ID} )
dataFile="ASA_*.N1"
m_in_dat="${MASTER}"
s_in_dat="${SLAVE}"
m_in_method="ASAR"
m_in_vol="dummy"
m_in_lea="dummy"
m_in_null="dummy"
s_in_vol="dummy"
s_in_lea="dummy"
s_in_null="dummy"
EOF

	# ready to lauch adore
	cd ${UUIDTMP}
	export ADORESCR=/opt/adore/scr; export PATH=${PATH}:${ADORESCR}:/usr/local/bin
	adore -u settings.set "m_readfiles; s_readfiles; settings apply -r m_orbdir=/tmp/ODR; m_porbits; s_porbits; m_crop; s_crop; coarseorb; dem make SRTM3 50 LAquila; settings apply -r raster_format=png; raster a m_crop -- -M1/5; raster a s_crop -- -M1/5; m_simamp; m_timing; coarsecorr; fine; reltiming; demassist; coregpm; resample; interfero; comprefpha; subtrrefpha; comprefdem; subtrrefdem; coherence; raster p subtrrefdem -- -M4/4; raster p subtrrefpha -- -M4/4; raster p interfero -- -M4/4; raster p coherence -- -M4/4 -cgray -b" &> /dev/stdout

	# removes unneeded files
	cd ${UUIDTMP}
	rm -rf *.res *.hgt *.drs *.temp *.ps *.DEM
	ciop-publish -m ${UUIDTMP}/*.*

	rm -rf ${UUIDTMP}
done 

ciop-log "INFO" "That's all folks"
