# Oracle Grants Remapper

``Oracle Grants Remmaper`` si collega ad una istanza oracle sorgente e crea un file ``.sql`` per la rigenerazione di grants i sinonimi da applicare su una istanza oracle di destinazione.
In base al file di configurazione passato come argomento, Oracle Grants Remmaper sostituisce i nomi degli schemi con quelli definiti nel file.

Il file di configurazione ha un formato simile a questo:

```
# Grants and Synonyms remapping
# ==============================

# Common settings
TMP_FILE=grants_and_syns.sql

# Oracle source data
SRC_TNS_NAME=UNIBOCCONI-PROD
SRC_SYSTEM_PWD=

SRC_GRANTEE_LIST=QUICK_DOCUMENT,QUICK_SUPPORT,QUICK_TALKS

# Oracle destination data - NOT IMPLEMENTED
TAR_TNS_NAME=BOCCONI_TEST
TAR_SYSTEM_PWD=

# Schema remapping start here. Don't move or change this section
# BEGIN
UNIBOCCONI_AGE20_PROD=UNIBOCCONI_AGE20_TEST
QUICK_DOCUMENT=QUICK_DOCUMENT
QUICK_SUPPORT=QUICK_SUPPORT

```
