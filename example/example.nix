  {}:{
    services.syncthing_wrapper = rec {
      default_versioning = {
        type = "simple";
        params.keep = "10";
      };
      devices = rec {
        all_pcs = {
          thinkpad = ids.thinkpad;
          thinknew = ids.thinknew;
          mainpc = ids.mainpc;
        };
        all_handys = {
          handy = ids.handy;

        };
        servers = { syncschlawiner = ids.syncschlawiner; };
        all_servers = servers // { tabula = ids.tabula; };

      };
      folders = with devices;
        with devices.all_handys;
        with devices.all_servers; {
          "Family" = {
            devices = (all_pcs // servers);
            paths = {
              "mainpc" = "/home/Family";
              "thinkpad" = "/home/Family";
              "thinknew" = "/home/Family";
            };
          };
          "Passwords" = {
            devices = (all_pcs // all_handys // servers);
            versioning = {
              type = "simple";
              params.keep = "100";
            };
          };
          "3d_printing" = [ (all_pcs // servers) ];
          "Documents" = [ (all_pcs // servers) ];
          "Notes" = [ (all_pcs // servers) ];
          "Downloads" = [ (all_pcs // servers) ];
          "Studium" = {
          devices = [ (all_pcs // uni)  ];
          paths = rec {
            "mainpc" = "/home/hannses/Documents/Studium/Semester1";
            "thinkpad" = mainpc;
            "thinknew" = mainpc;
          };
          };
        };
    };

    services.syncthing = {
      settings = {
        options = {
          urAccepted = -1; # do not send reports
          relaysEnabled = true;
        };
      };
      key = lib.mkIf(config.services.syncthing.enable) config.age.secrets."syncthing_key_${config.networking.hostName}".path;
      cert = lib.mkIf(config.services.syncthing.enable) config.age.secrets."syncthing_cert_${config.networking.hostName}".path;
    };
}
