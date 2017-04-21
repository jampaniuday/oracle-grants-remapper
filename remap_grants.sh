#!/bin/bash

display_usage() {
	echo "Config file unspecified"
	echo "  Usage: [profile]"
  echo "  ex: $0 FROM_PROD_TO_TEST.cfg"
	}


# Parameters: TNS_NAME, SYSTEM_PWD, SOURCE_GRANTOR, REMAPPED_GRANTOR, SOURCE_GRANTEE, REMAPPED_GRANTEE
save_grants() {
TNS_NAME=$1
SYSTEM_PWD=$2
SOURCE_GRANTOR=$3
SOURCE_GRANTEE=$4
REMAP_LIST=$5

# https://docs.oracle.com/cd/B19306_01/server.102/b14357/ch12040.htm
sqlplus -s system/$SYSTEM_PWD@$TNS_NAME << EOF
set verify off
set heading off
set feedback off
set line 2000
set trim on
set trims on
set serveroutput on
spool ./${TMP_FILE} append

declare
	  source_grantor dba_tab_privs.grantor%TYPE := '$SOURCE_GRANTOR';
	  source_grantee dba_tab_privs.grantee%TYPE := '$SOURCE_GRANTEE';

		junk varchar2(10) := '';

	  command varchar2(2000) := '';

		function decode_schema (p_todecode in VARCHAR2, r_val in VARCHAR2)
		return varchar2
		is
		max_iterations number := 100;
    pointer number := 1;

		p_val varchar2(2000);
		item varchar2(2000);
		sep_pos number;
		len_pos number;
		retval varchar2(2000) := 'unknow';
		to_find varchar2(2000);
		to_replace varchar2(2000);

		begin
				p_val:=r_val;
		    while (max_iterations != 0)
		    loop

		       pointer := INSTR(p_val,',');

		       -- Non ci sono virgole quindi esco
		       if pointer = 0 then
		            exit;
		       end if;

		       item := substr(p_val, 1, pointer - 1);

		       p_val := substr(p_val, pointer +1);

		       sep_pos := INSTR(item,'=', 1);
		       len_pos := length(item);

		       to_find :=  substr(item, 1, sep_pos-1);
		       to_replace := substr(item, sep_pos+1, len_pos-sep_pos);

		       if to_find = p_todecode then
		            retval:=to_replace;
		            exit;
		       end if;

		       max_iterations := max_iterations - 1 ;
		    end loop;

		return retval;

		end decode_schema;

begin
		DBMS_OUTPUT.ENABLE (buffer_size => NULL);

		dbms_output.put_line('-- ');
		dbms_output.put_line('-- =============================================');
		dbms_output.put_line('-- *** REMAP FOR '|| source_grantee);
		dbms_output.put_line('-- =============================================');

		dbms_output.put_line('-- ');
		dbms_output.put_line('-- *** GRANTS FOR '|| source_grantee);
		dbms_output.put_line('-- *** -----------------------------------------');
		-- Export GRANTS
		FOR cur IN
		(
				SELECT  'GRANT ' || privilege  || ' ON ' || '"#owner#"' || '.'
				                   || '"' || table_name || '"' || ' TO ' || '"#grantee#"'
				                   || DECODE(grantable, 'YES', ' WITH GRANT OPTION', NULL) || ';'  AS sql_cmd,
				                owner,
				                grantee
				            FROM dba_tab_privs ksv
				            WHERE grantee = source_grantee
				            -- AND privilege in ('SELECT', 'EXECUTE')
				            and (grantor = source_grantor or source_grantor is null)
				            ORDER BY 1)
				loop

				command := cur.sql_cmd;
				command := replace(command, '#owner#', decode_schema(cur.owner, '$REMAP_LIST'));
				command := replace(command, '#grantee#', decode_schema(cur.grantee, '$REMAP_LIST'));

				if instr(command, 'unknow', 1) != 0 then
					dbms_output.put_line('-- Warning: ' || cur.owner || ' or ' || cur.grantee || ' not remapped');
					dbms_output.put_line('-- ' || command);
				else
					dbms_output.put_line(command);
				end if;

		end loop;

		-- Export Synonyms
		dbms_output.put_line('-- ');
		dbms_output.put_line('-- *** SYNONYMS ON '|| source_grantee);
		dbms_output.put_line('-- *** -----------------------------------------');

		FOR cur IN
		(
				select 'CREATE OR REPLACE SYNONYM ' || '"#owner#"' || '."'|| synonym_name || '" FOR ' || '"#table_owner#"' || '."' || table_name ||'";' as sql_cmd,
				owner, table_owner
				from
					all_synonyms
				where
					table_owner != owner and owner=source_grantee)

				loop

				command := cur.sql_cmd;
				command := replace(command, '#owner#', decode_schema(cur.owner, '$REMAP_LIST'));
				command := replace(command, '#table_owner#', decode_schema(cur.table_owner, '$REMAP_LIST'));

				if instr(command, 'unknow', 1) != 0 then
					dbms_output.put_line('-- Warning: ' || cur.owner || ' or ' || cur.table_owner || ' not remapped');
					dbms_output.put_line('-- ' || command);
				else
					dbms_output.put_line(command);
				end if;

		end loop;

	end;
	/

	spool off
EOF
}

# Script argument check. If less than two arguments supplied, display usage
if [ $# -ne 1 ]; then
		display_usage
		exit 1
fi

# Check whether user had supplied -h or --help . If yes display usage
if [[ ( $# == "--help") ||  $# == "-h" ]]
then
  display_usage
	exit 0
fi

# Load configuration file
if [ -f ${1} ]; then
   source ./${1}
else
   echo "File ${1} not found"
	 display_usage
   exit
fi

# I ask for the source password if it is not set
if [ -z "$SRC_SYSTEM_PWD" ]; then
  while [[ $SRC_SYSTEM_PWD == '' ]]
  do
    read -p ">> Enter SYSTEM password for Source Database $SRC_TNS_NAME: " SRC_SYSTEM_PWD
  done
fi

# I ask for the target password if it is not set
# if [ -z "$TAR_SYSTEM_PWD" ]; then
#  while [[ $TAR_SYSTEM_PWD == '' ]]
#  do
#    read -p ">> Enter SYSTEM password for Destination Database $TAR_TNS_NAME: " TAR_SYSTEM_PWD
#  done
#fi

# Oracle connection check
echo "exit" | sqlplus -L system/$SRC_SYSTEM_PWD@$SRC_TNS_NAME | grep Partitioning > /dev/null
if [ $? -ne 0 ]
then
   echo "ERROR: Connection failed!!!"
   exit
fi

# I create a list of mappings to be made
start_reading=0
mapping_variable=""
while read -r line
do
	if [ "${line}" = "# END" ]; then
	 start_reading=0
	fi

	if [ $start_reading -eq 1 ]; then
	 mapping_variable=$mapping_variable"$line,"
	fi

 if [ "${line}" = "# BEGIN" ]; then
	 start_reading=1
 fi

done <"$1"

# Remove temp file if exist
[ -e ${TMP_FILE} ] && rm ${TMP_FILE}

# echo "> BEGIN: Apply script to $TNS_NAME"

# Reads a string like a, b, c, and cycles on each element
IFS=',' read -ra ADDR <<< "$SRC_GRANTEE_LIST"
for i in "${ADDR[@]}"; do
		save_grants $SRC_TNS_NAME $SRC_SYSTEM_PWD '' "$i" "${mapping_variable}"
done

# echo "> END"
