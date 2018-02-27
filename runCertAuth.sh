#!/bin/bash
set -u #no use of undeclared vars
set -e #exit on error

# SSL / https setup completion - proof of concept:

# ==================== 1 :: NAME THE CERTIFICATES TO BUILD ===================================
#
# CONTEXT: We use our own CA to issue and sign a certificate for one of our servers. Therefore
#          we need two certificates: 1 representing our own CA, and another that the target
#          server will use.
#
# NOTE: To keep track of keys and certs, a naming convention + increments might be useful:
# example CA: <applicationName>-rootCA-<env>-<seq#>.[key|csr|pem|crt]
# example server cert: <app>-<server>-<env>-<seq#>.[key|csr|pem|crt]
# !!! DON'T FORGET TO INCREMENT THE SEQ# !!!
# ============================================================================================
ROOTCA_NAME=xxx-rootCA-dev-1            # the name for our own single-level CA
TARGET=xxx-serverxxx-dev-1              # name of cert to generate for a target server 


# ==================== 2 :: PATH SETUP ========================================================
# Since openssl is a medusa-headed swiss-army knife, rather than fight with all it's
# commandline options, it's generally best to tuck all the parameters away in config
# files. We'll need the paths to these, as well as paths to our ssl-related folders.
# =============================================================================================
SSLDIR=/etc/ssl/certs/my-application                    # where keys, CSRs and certs are stored
ROOTCA_CSR_CONFIG=/path/to/sample-root-csr.cfg          # for building request for CA cert
SERVER_CSR_CONFIG=/path/to/sample-server-csr.cfg        # for building request for regular cert
SERVER_EXT_CONFIG=/path/to/sample-server-ext.cfg        # x509 cert extensions

if [ "$1" != "noroot" ]; then
    # ==================== 3 :: KEY CEREMONY - PRIVATE, SINGLE LEVEL CA ===========================
    # We create a key-pair that will represent our tiny CA.
    # (Preferring aes over des as the latter is outdated).
    # =============================================================================================
    openssl genrsa -aes128 -out "${SSLDIR}/${ROOTCA_NAME}.key" 2048

    # ==================== 4 :: GENERATE SELF-SIGNED ROOT CA CERTIFICATE ==========================
    # This is the certificate that browsers + other clients will look to, when validating any certs
    # received from our servers. Note that the key generated in the previous step is used to sign 
    # the certificate generated in this step. Openssl detects that we are self-signing and 
    # automatically sets 'CA:TRUE' in the relevant blocks. Non-obvious flags:
    # -new => generate new request (instead of looking to for an existing request as file input)
    # -nodes => do not encrypt the cert (this also means no passphrase is needed)
    # -x509 => outputs a self signed certificate instead of a certificate request
    # -sha256 => the signature hashing algorithm
    # =============================================================================================
    openssl req -config "${ROOTCA_CSR_CONFIG}" -x509 -new -nodes -key "${SSLDIR}/${ROOTCA_NAME}.key" -sha256 -days 365 -out "${SSLDIR}/${ROOTCA_NAME}.pem"

    echo "###################################"
    echo "##     root CA cert created      ##"
    echo "###################################"
    openssl x509 -noout -text -in "${SSLDIR}/${ROOTCA_NAME}.pem" #does nothing except display to screen.
fi

# ==================== 5 :: KEY CEREMONY - LOCAL / DEV SERVER =================================
# We create a key-pair that will represent a server in non-production environment
# Note for simplicity -aesnnn arg is left out this time => no encryption, no passphrase.
# =============================================================================================
openssl genrsa -out "${SSLDIR}/${TARGET}.key" 2048

# ==================== 6 :: GENERATE CSR FROM THE NEW KEY  ====================================
# Essentially, a CSR is created for the server, as if there was no knowledge of the root CA
# created earlier... i.e. this CSR could ostensibly be sent to a public CA.
# NOTE: the '-key' arg allows us to provide the server's key-pair (created in previous step).
# NOTE: this time -x509 arg is missing because this server is not going to sign for itself.
# =============================================================================================
openssl req -config "${SERVER_CSR_CONFIG}" -new -key "${SSLDIR}/${TARGET}.key" -out "${SSLDIR}/${TARGET}.csr"

# ==================== 7 :: OUR CA ISSUES THE REQUESTED CERT & SIGNS IT =======================
# This generates the ssl certificate for the target server:
# note how we issue the cert with our own CA and sign it with our CA's private key.
# -CAcreateserial seems to create a .srl file for generating serial numbers for the certs.
# things break if you leave it out. (shrug).
# =============================================================================================
openssl x509 -extfile "${SERVER_EXT_CONFIG}" -req -in "${SSLDIR}/${TARGET}.csr" \
-CA "${SSLDIR}/${ROOTCA_NAME}.pem" -CAkey "${SSLDIR}/${ROOTCA_NAME}.key" -out "${SSLDIR}/${TARGET}.crt" \
-CAcreateserial -days 365 -sha256

echo "###################################"
echo "##   server SSL cert created     ##"
echo "###################################"
openssl x509 -noout -text -in "${SSLDIR}/${TARGET}.crt" #does nothing except display to screen.

echo "DONE."
ls -al ${SSLDIR}

echo " ********* !!! (1) REMEMBER to add ${SSLDIR}/${ROOTCA_NAME}.pem to certificate stores incl browser certs!! *******"
echo " ********* !!! (2) REMEMBER to update environment settings + web server configs with new ssl files and restart web servers! *******"
echo " ********* !!! (3) Certs work OK? Like to keep them? Then [SUDO CHMOD 640] all the generated files ASAP!! ******"
echo " ********* !!! (4) For extra security, you can delete the your root CA keys so no further certs can be signed by it. ******"