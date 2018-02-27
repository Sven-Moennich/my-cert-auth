# my-cert-auth
This is a simple script that encapsulates some stuff I learned about using openssl to generate ssl certificates for a dev environment.

### Motivation ###
Although self-signed certificates can be created for non-prod environments, I quickly learned that most tools and browsers don't like them. The workaround (short of being a full-blown, proper CA that publishes to public repositories) is to be your own mini CA. This script creates the keys and certs needed for your own own local root CA that signs certificates for machines in your tiny little jurisdiction :-)

## HOW-TO:
1. Download the files
1. update the .cfg files with meaningful values and place them wherever you like
1. update runCertAuth.sh with the desired names for your certificates, as well as the paths to the .cfg files. In other words, update:
```
ROOTCA_NAME
TARGET
SSLDIR
ROOTCA_CSR_CONFIG
SERVER_CSR_CONFIG
SERVER_EXT_CONFIG
```
4. get to a terminal and run the script: `sh runCertAuth.sh`. This will generate your CA certificate and the key and cert for your server of choice. If you have ran the script before and only want spit out new server certificates, use `sh runCertAuth noroot`.

That's all folks!!
