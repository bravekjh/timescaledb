CREATE DATABASE single;

\c single
CREATE EXTENSION IF NOT EXISTS timescaledb;

CREATE TABLE devices (
    id TEXT PRIMARY KEY,
    floor INTEGER
);

CREATE TABLE PUBLIC."two_Partitions" (
  "timeCustom" BIGINT NOT NULL,
  device_id TEXT NOT NULL REFERENCES devices(id),
  series_0 DOUBLE PRECISION NOT NULL CHECK(series_0 > 0),
  series_1 DOUBLE PRECISION NULL,
  series_2 DOUBLE PRECISION NULL,
  series_bool BOOLEAN NULL,
  PRIMARY KEY("timeCustom", device_id),
  UNIQUE("timeCustom", device_id, series_2)
);

ALTER TABLE  "two_Partitions" ADD COLUMN device_id_2 TEXT NOT NULL;

ALTER TABLE "two_Partitions" ADD CONSTRAINT two_Partitions_device_id_2_fkey
FOREIGN KEY (device_id_2) REFERENCES devices(id);

CREATE INDEX ON PUBLIC."two_Partitions" (device_id, "timeCustom" DESC NULLS LAST) WHERE device_id IS NOT NULL;
CREATE INDEX ON PUBLIC."two_Partitions" ("timeCustom" DESC NULLS LAST, series_0) WHERE series_0 IS NOT NULL;
CREATE INDEX ON PUBLIC."two_Partitions" ("timeCustom" DESC NULLS LAST, series_1)  WHERE series_1 IS NOT NULL;
CREATE INDEX ON PUBLIC."two_Partitions" ("timeCustom" DESC NULLS LAST, series_2) WHERE series_2 IS NOT NULL;
CREATE INDEX ON PUBLIC."two_Partitions" ("timeCustom" DESC NULLS LAST, series_bool) WHERE series_bool IS NOT NULL;
CREATE INDEX ON PUBLIC."two_Partitions" ("timeCustom" DESC NULLS LAST, device_id);

SELECT * FROM create_hypertable('"public"."two_Partitions"'::regclass, 'timeCustom'::name, 'device_id'::name, associated_schema_name=>'_timescaledb_internal'::text, number_partitions => 2, chunk_time_interval=>_timescaledb_internal.interval_to_usec('1 month'));

INSERT INTO devices(id,floor) VALUES
('dev1', 1),
('dev2', 2),
('dev3', 3);

INSERT INTO public."two_Partitions"("timeCustom", device_id, device_id_2, series_0, series_1, series_2) VALUES
(1257987600000000000, 'dev1', 'dev2', 1.5, 2, 2),
(1257894000000000000, 'dev2', 'dev2', 1.5, 1, 3),
(1257987600000000000, 'dev3', 'dev2', 1.5, 1, 1),
(1257894002000000000, 'dev1', 'dev2', 2.5, 3, 4);

INSERT INTO "two_Partitions"("timeCustom", device_id, device_id_2, series_0, series_1, series_2) VALUES
(1257894100000000000, 'dev2', 'dev2', 1.5, 2, 6);

CREATE TABLE PUBLIC.hyper_timestamp (
  time timestamp NOT NULL,
  device_id TEXT NOT NULL,
  value int NOT NULL,
  EXCLUDE USING btree (
        "time" WITH =, device_id WITH =
   ) WHERE (value > 0)
);

SELECT * FROM create_hypertable('hyper_timestamp'::regclass, 'time'::name, 'device_id'::name, number_partitions => 2,
    chunk_time_interval=> _timescaledb_internal.interval_to_usec('1 minute'));

--some old versions use more slice_ids than newer ones. Make this uniform
ALTER SEQUENCE _timescaledb_catalog.dimension_slice_id_seq RESTART WITH 100;

INSERT INTO hyper_timestamp VALUES
('2017-01-20T09:00:01', 'dev1', 1),
('2017-01-20T08:00:01', 'dev2', 2),
('2016-01-20T09:00:01', 'dev1', 3);

-- DROP some chunks to test metadata cleanup
DROP TABLE _timescaledb_internal._hyper_1_2_chunk;
DROP TABLE _timescaledb_internal._hyper_1_3_chunk;
