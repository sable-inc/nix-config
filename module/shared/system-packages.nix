{ pkgs }:
[
  pkgs.git
  pkgs.google-chrome
  pkgs.slack
  pkgs.spotify
  (pkgs.google-cloud-sdk.withExtraComponents [
    pkgs.google-cloud-sdk.components.gke-gcloud-auth-plugin
  ])
]
