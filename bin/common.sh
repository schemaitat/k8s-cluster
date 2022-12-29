function trap_add() {
 # based on https://stackoverflow.com/questions/3338030/multiple-bash-traps-for-the-same-signal
 # but: prepends new cmd rather than append it, changed var names and eliminated messages

   local cmd_to_add signal

   cmd_to_add=$1; shift
   for signal in "$@"; do
      trap -- "$(
         # print the new trap command
         printf '%s\n' "${cmd_to_add}"
         # helper fn to get existing trap command from output
         # of trap -p
         extract_trap_cmd() { printf '%s\n' "$3"; }
         # print existing trap command with newline
         eval "extract_trap_cmd $(trap -p "${signal}")"
      )" "${signal}"
   done
}

function errexit_msg {
   if [ -o errexit ]; then
      log_error "Exiting script [`basename $0`] due to an error executing the command [$BASH_COMMAND]."
   else
      log_debug "Trap [ERR] triggered in [`basename $0`] while executing the command [$BASH_COMMAND]."
   fi
}

# Save standard out to a new descriptor
exec 3>&1

# Includes
source bin/colors-include.sh
source bin/log-include.sh

log_debug "Working directory: $(pwd)"

binaries="python3 curl yq jq helm kubectl linode-cli"
log_debug "Checking if all of $binaries are available."
for bin in $binaries; do
   if [ ! $(which $bin) ]; then
      log_error "$bin not found on the current PATH"
      exit 1
   fi
done


export TMP_DIR=$(mktemp -d -t temp.XXXXXXXX)
if [ ! -d "$TMP_DIR" ]; then
    log_error "Could not create temporary directory [$TMP_DIR]"
    exit 1
fi
log_debug "Temporary directory: [$TMP_DIR]"

# Delete the temp directory on exit
function cleanup {
    KEEP_TMP_DIR=${KEEP_TMP_DIR:-false}
    if [ "$KEEP_TMP_DIR" != "true" ]; then
      rm -rf "$TMP_DIR"
      log_debug "Deleted temporary directory: [$TMP_DIR]"
    else
      log_info "TMP_DIR [$TMP_DIR] was not removed"
    fi
}

trap_add cleanup EXIT
trap_add errexit_msg ERR

export -f trap_add
export -f errexit_msg