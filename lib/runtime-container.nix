# Shared helpers for runtime Docker image pins (Git SSOT + /var/lib/.../deploy/*-image).
{ lib, pkgs }:
let
  inherit (lib) concatMapStringsSep;

  imageTagFromRef = image: lib.last (lib.splitString ":" image);
in
{
  inherit imageTagFromRef;

  mkSyncRuntimeImageActivation =
    {
      name,
      deployDir,
      instances,
    }:
    let
      syncBody = concatMapStringsSep "\n" (
        instance:
        let
          env = instance.env;
          tag = imageTagFromRef instance.image;
        in
        ''
          install -d -m 0755 ${deployDir}
          WANTED_${env}='${tag}'
          FILE_${env}="${deployDir}/${env}-image"
          if [ ! -f "$FILE_${env}" ] || [ "$(cat "$FILE_${env}")" != "$WANTED_${env}" ]; then
            echo "$WANTED_${env}" > "$FILE_${env}"
          fi
        ''
      ) instances;
    in
    {
      "${name}" = {
        text = syncBody;
      };
    };

  mkRestartContainerScript =
    {
      scriptName,
      deployDir,
      imageRepo,
      instances,
    }:
    let
      envList = concatMapStringsSep "|" (i: i.env) instances;

      envCases = concatMapStringsSep "\n" (
        i:
        ''
          ${i.env})
            CONTAINER="${i.containerName}"
            HOST_PORT="${toString i.hostPort}"
            CONTAINER_PORT="${toString i.containerPort}"
            DATA_VOLUME="${i.dataVolume}"
            ENV_FILE="${i.envFile}"
            NETWORK="${i.network}"
            EXTRA_RUN_ARGS=${i.extraRunArgs or ""}
            ;;
        ''
      ) instances;
    in
    pkgs.writeShellScriptBin scriptName ''
      set -euo pipefail

      ENV="''${1:-}"
      TAG_ARG="''${2:-}"

      case "$ENV" in
        ${envList}) ;;
        *)
          echo "usage: ${scriptName} <${envList}> [image-tag]" >&2
          exit 1
          ;;
      esac

      case "$ENV" in
      ${envCases}
      esac

      DEPLOY_DIR="${deployDir}"
      IMAGE_FILE="$DEPLOY_DIR/''${ENV}-image"
      ${pkgs.coreutils}/bin/install -d -m 0755 "$DEPLOY_DIR"

      if [ -n "$TAG_ARG" ]; then
        echo "$TAG_ARG" > "$IMAGE_FILE"
      elif [ -f "$IMAGE_FILE" ]; then
        TAG_ARG=$(cat "$IMAGE_FILE")
      else
        echo "error: no image tag in $IMAGE_FILE and none passed on CLI" >&2
        exit 1
      fi

      FULL_IMAGE="${imageRepo}:''${TAG_ARG}"
      DOCKER="${pkgs.docker}/bin/docker"

      echo "Pulling $FULL_IMAGE ..."
      "$DOCKER" pull "$FULL_IMAGE"

      echo "Recreating container $CONTAINER ..."
      "$DOCKER" stop "$CONTAINER" 2>/dev/null || true
      "$DOCKER" rm "$CONTAINER" 2>/dev/null || true

      # shellcheck disable=SC2086
      "$DOCKER" run -d \
        --name "$CONTAINER" \
        --network "$NETWORK" \
        -p "''${HOST_PORT}:''${CONTAINER_PORT}" \
        --env-file "$ENV_FILE" \
        -v "''${DATA_VOLUME}" \
        $EXTRA_RUN_ARGS \
        "$FULL_IMAGE"

      echo "Running $CONTAINER → $FULL_IMAGE"
    '';
}
