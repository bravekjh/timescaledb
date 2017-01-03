--This file provides a utility for executing dblink commands transactionally (almost) with the local transaction.
--Any command executed by the _sysinternal.meta_transaction_exec command will be committed on the meta node only
--when the local transaction commits.


--Called by _sysinternal.meta_transaction_exec to start a transaction. Can be called directly to start a transaction 
--if you need to use some of the more custom dblink functions. Returns the dblink connection name for the started transaction. 
CREATE OR REPLACE FUNCTION _sysinternal.meta_transaction_start()
    RETURNS TEXT LANGUAGE PLPGSQL VOLATILE AS
$BODY$
DECLARE
    conn_exists BOOLEAN;
    conn_name TEXT = 'meta_conn';
BEGIN
    SELECT conn_name = ANY (conn) INTO conn_exists
    FROM dblink_get_connections() conn;

    IF conn_exists IS NULL OR NOT conn_exists THEN
        --tells c code to commit in precommit.
        PERFORM set_config('io.commit_meta_conn_in_precommit_hook', 'true', true);
        PERFORM dblink_connect(conn_name, get_meta_server_name());
        PERFORM dblink_exec(conn_name, 'BEGIN');
    END IF;

    RETURN conn_name;
END
$BODY$;

--This should be called to execute code on a meta node. It is not necessary to
--call _sysinternal.meta_transaction_start() beforehand. The code excuted by this function
--will be automatically committed when the local transaction commits (in pre-commit).
CREATE OR REPLACE FUNCTION  _sysinternal.meta_transaction_exec(sql_code text)
    RETURNS VOID LANGUAGE PLPGSQL VOLATILE AS
$BODY$
DECLARE
    conn_name TEXT;
BEGIN
    SELECT _sysinternal.meta_transaction_start() INTO conn_name;
    
    PERFORM * FROM dblink(conn_name, sql_code) AS t(r TEXT);
END
$BODY$;

--Should be called internally by pre-commit hook only. Should not be called directly otherwise.
CREATE OR REPLACE FUNCTION _sysinternal.meta_transaction_end()
    RETURNS VOID LANGUAGE PLPGSQL VOLATILE AS
$BODY$
DECLARE
    conn_name TEXT = 'meta_conn';
BEGIN
    PERFORM dblink_exec(conn_name, 'COMMIT');
    PERFORM dblink_disconnect(conn_name);
END
$BODY$;

