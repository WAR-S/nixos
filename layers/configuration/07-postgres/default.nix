{ config, pkgs, lib, infra, ... }:

let
  pg = infra.postgres;
  gateway = infra.network.ap.gateway;
  pgDataDir = "/var/lib/postgres/data";
  pgInitSql = pkgs.writeText "postgres-init.sql" ''
    CREATE ROLE ${pg.user} LOGIN PASSWORD '${pg.password}';
    CREATE DATABASE "${pg.database}" OWNER ${pg.user} ENCODING 'UTF8'
      LC_COLLATE 'en_US.UTF-8' LC_CTYPE 'en_US.UTF-8' TEMPLATE template1;
    \connect "${pg.database}"
    CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
  '';
in
{
  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_16;
    dataDir = pgDataDir;
    enableTCPIP = true;
    authentication = ''
      # TYPE  DATABASE        USER            ADDRESS                 METHOD
      local   all             all                                     trust
      host    postgres        postgres        ${gateway}/32          md5
      host    all             all             127.0.0.1/32           trust
      host    ${pg.database}  ${pg.user}      0.0.0.0/0              md5
      local   replication     all                                     trust
      host    replication     all             127.0.0.1/32           trust
      host    replication     all             ::1/128                trust
    '';
    settings = {
      listen_addresses = lib.mkForce pg.listenAddress;
      max_connections = 100;
      shared_buffers = "128MB";
      dynamic_shared_memory_type = "posix";
      max_wal_size = "1GB";
      min_wal_size = "80MB";
      logging_collector = true;
      log_directory = "logs";
      log_filename = "postgresql-%a.log";
      log_rotation_age = "1d";
      log_rotation_size = 0;
      log_truncate_on_rotation = true;
      log_timezone = "UTC";
      datestyle = "iso, mdy";
      timezone = "UTC";
      default_text_search_config = "pg_catalog.english";
      shared_preload_libraries = "pg_stat_statements";
      "pg_stat_statements.track" = "all";
    };
    initialScript = pgInitSql;
  };

  systemd.tmpfiles.rules = [
    ''d /var/lib/postgres 0750 postgres postgres -''
    ''d ${pgDataDir} 0700 postgres postgres -''
  ];

  systemd.services.postgresql = {
    after = [ "wifi-ap-wait-ip.service" ];
    wants = [ "wifi-ap-wait-ip.service" ];
  };
}
