### Getting Started 

To run this application, you will need a Developer Cloud Sandbox that can be requested from [Terradue's Portal](http://www.terradue.com/partners), provided user registration approval. 

### Installation

#### using rpms
Log on the developer sandbox. Download the rpm package from https://github.com/Terradue/dcs-doris-l1-stack/releases . Install the package by running these commands in a shell:

```bash
sudo yum -y downgrade geos-3.3.2
sudo yum -y install dcs-doris-l1-stack-<version>-ciop.x86_64.rpm
```

#### using maven

Log on the developer sandbox and run these commands in a shell:

```bash
sudo yum -y downgrade geos-3.3.2
sudo yum -y install adore-t2

cd
git clone git@github.com:Terradue/dcs-doris-l1-stack.git

cd dcs-doris-l1-stack
mvn install
```

### Submitting the workflow

Run this command in a shell:

```bash
ciop-simwf
```

Or invoke the Web Processing Service via the Sandbox dashboard providing a master/slave product url and a project name (e.g. LAquila)

