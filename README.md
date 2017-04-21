# Oracle Grants Remapper

``Oracle Grants Remmaper`` si collega ad una istanza oracle sorgente e crea un file ``.sql`` per la rigenerazione di grants i sinonimi da applicare su una istanza oracle di destinazione.
In base al file di configurazione passato come argomento, Oracle Grants Remmaper sostituisce i nomi degli schemi con quelli definiti nel file.

Il file di configurazione ha un formato simile a questo:

```
# Grants and Synonyms remapping
# ==============================

# Common settings
SQL_FILE=grants_and_syns.sql

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
# END

```

* SQL_FILE: Nome del file sql che viene generato
* SRC_TNS_NAME: Nome del TNS_NAMES definito nel tnsnames.ora del client oracle
* SRC_SYSTEM_PWD: Password dell'utente SYSTEM (Se non valorizzata viene chiesta in fase di esecuzione dello script)
* SRC_GRANTEE_LIST=Lista degli schemi per i quali rigenerare i grant e i sinonimi. Vengono creati i grants verso questo schema e i sinonimi presenti in questo schema che referenziano oggetti verso schemi diversi

In coda a questi parametri c'e' una sezione in cui si effettua il remapping vero e proprio degli schemi.

Se ad esempio sull'istanza di origine dovesse esistere un grant come questo:

```sql
GRANT EXECUTE ON "ESSE3_UNIBOCCONI_PROD"."TABELLA_01" TO "ESSE3_UNIBOCCONI_PROD_READ";
CREATE OR REPLACE SYNONYM "ESSE3_UNIBOCCONI_PROD_READ"."SYN_TABELLA_01" FOR "ESSE3_UNIBOCCONI_PROD"."TABELLA_01";
```

sulla base del file di configurazione riportato in esempio verra' creato il seguente script

```sql
GRANT EXECUTE ON "ESSE3_UNIBOCCONI_PREPROD"."TABELLA_01" TO "ESSE3_UNIBOCCONI_PREPROD_READ";
CREATE OR REPLACE SYNONYM "ESSE3_UNIBOCCONI_PREPROD_READ"."SYN_TABELLA_01" FOR "ESSE3_UNIBOCCONI_PREPROD"."TABELLA_01";
```

