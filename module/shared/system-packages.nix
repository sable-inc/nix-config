{ pkgs }:
[
  pkgs.git
  pkgs.slack
  pkgs.spotify
  pkgs.vim
  (pkgs.google-cloud-sdk.withExtraComponents [
    pkgs.google-cloud-sdk.components.gke-gcloud-auth-plugin
  ])
]
