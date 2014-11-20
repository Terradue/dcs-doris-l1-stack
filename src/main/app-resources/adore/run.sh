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
		$ERR_WRONGPROD) msg="Wrong product provided as input. Please use ASA_IMS_1P";;
		*) msg="Unknown error";;
	esac

	[ "$retval" != "0" ] && ciop-log "ERROR" "Error $retval - $msg, processing aborted" || ciop-log "INFO" "$msg"
	exit $retval
}
trap cleanExit EXIT

# path and master/slave variable definition
export ADORESCR=/opt/adore/scr; export PATH=${PATH}:${ADORESCR}:/usr/local/bin

UUID=`uuidgen`
UUIDTMP="/tmp/${UUID}"
MASTER="`ciop-getparam adore_master`"
PROJECT="`ciop-getparam adore_project`"

# let's check if the correct product was provided
[ "`basename ${MASTER} | cut -c 1-10`" != "ASA_IMS_1P" ] && exit $ERR_WRONGPROD

# creates the adore directory structure
ciop-log "INFO" "creating the directory structure"
mkdir -p ${UUIDTMP}
mkdir ${UUIDTMP}/data
mkdir ${UUIDTMP}/${PROJECT}
mkdir ${UUIDTMP}/data/master
mkdir ${UUIDTMP}/data/slaves

ciop-log "INFO" "basedir is ${UUIDTMP}"

# copies the ODR files
ciop-log "INFO" "copying the ODR files"
tar xvfz /application/adore/files/ODR.tgz -C ${UUIDTMP}

# retrieves the files
ciop-log "INFO" "downloading master [${MASTER}]"
MASTER=`ciop-copy -f -O ${UUIDTMP}/data/master ${MASTER}`
res=$?

while read slave
do
	# let's check if the correct product was provided
	[ "`basename ${MASTER} | cut -c 1-10`" != "ASA_IMS_1P" ] && exit $ERR_WRONGPROD

	# let's get the file date from the name
	SLAVE_ID=`basename ${slave} | cut -c 15-22`

	# creates the directories for the file and the processing
	mkdir ${UUIDTMP}/data/slaves/${SLAVE_ID}
	mkdir ${UUIDTMP}/${PROJECT}/master_${SLAVE_ID}

	ciop-log "INFO" "downloading slave [${slave}]"
	SLAVE=`ciop-copy -f -O ${UUIDTMP}/data/slaves/${SLAVE_ID} ${slave}`

	# writing the adore settings.set file
	cat > ${UUIDTMP}/${PROJECT}/master_${SLAVE_ID}/settings.set <<EOF
projectFolder="${UUIDTMP}/${PROJECT}/master_${SLAVE_ID}"
runName="master_${SLAVE_ID}"
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
	cd ${UUIDTMP}/${PROJECT}/master_${SLAVE_ID}
	adore -u settings.set "m_readfiles; settings apply -r m_orbdir=${UUIDTMP}/ODR; m_porbits; s_readfiles; s_porbits; m_crop; s_crop; coarseorb; dem make SRTM3 50 LAquila; s raster_format; settings apply -r raster_format=png; raster a m_crop -- -M1/5; raster a s_crop -- -M1/5; m_simamp; m_timing; coarsecorr; fine; reltiming; demassist; coregpm; resample; interfero; comprefpha; subtrrefpha; comprefdem; subtrrefdem; coherence; raster p subtrrefdem -- -M4/4; raster p subtrrefpha -- -M4/4; raster p interfero -- -M4/4; raster p coherence -- -M4/4 -cgray -b"

# removes unneeded files
cd ${UUIDTMP}/${PROJECT}/master_${SLAVE_ID}
rm -rf *.res *.hgt *.drs *.temp *.ps *.DEM
ciop-publish -m cd ${UUIDTMP}/${PROJECT}/master_${SLAVE_ID}/*.*

done

#rm -rf ${UUIDTMP}

ciop-log "INFO" "That's all folks"
