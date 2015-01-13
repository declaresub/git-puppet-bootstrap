#! /bin/bash


#This script updates the puppet configuration from the git repository, then runs puppet.


if ! id -u >> /dev/null; then
    echo "This script must be executed as root."
    exit 1
fi

#parse arguments.
while [ $# -ge 1 ]; do
        case "$1" in
                --)
                    # No more options left.
                    shift
                    break
                   ;;
                -q|--quiet)
                        QUIET="true"
                        shift
                        ;;
                -d|--debug)
                        PUPPET_DEBUG="--debug"
                        shift
                        ;; 
        esac

        shift
done


PUPPET_LINK="/etc/puppet"
REPO_NAME="server.git"
GIT_REPO="$(getent passwd git | cut -d: -f6)/$REPO_NAME"

if [[ -n "$QUIET" ]]; then
    #redirect stdout to /dev/null.
    exec 1>/dev/null
fi

cd "${GIT_REPO}"

if [[ -L "$PUPPET_LINK" ]]; then
    CURRENT_PUPPET_DIR=$(readlink "$PUPPET_LINK")
    CURRENT_COMMIT=$(printf $CURRENT_PUPPET_DIR | cut -d '.' -f 2)
else
    #in this case, make sure there is nothing there.
    if [[ -e $PUPPET_LINK ]]; then
        echo "There is a file at $PUPPET_LINK that should not be there."
        exit 1
    fi
    echo "$PUPPET_LINK is not a link."
    CURRENT_COMMIT=""
fi
REPO_COMMIT=$(git rev-parse --short HEAD)

if [[ -z "$CURRENT_COMMIT" || "$REPO_COMMIT" != "$CURRENT_COMMIT" ]]; then
    echo "There is a new puppet commit."
    
    echo "Creating temporary directory."
    TMP_DIR=$(mktemp -d /root/serverrepo.XXXXXX)
    if [[ ! -d $TMP_DIR ]]; then
        echo "Unable to create temporary directory.  Exiting." >&2
        exit 1
    fi
    trap 'rm -r "$TMP_DIR"' EXIT

    echo "Dumping git working copy to $TMP_DIR."
    git archive --format=tar HEAD  | (pushd $TMP_DIR >> /dev/null && tar xf -)
    NEW_DIR="$PUPPET_LINK.$REPO_COMMIT"
    
    echo "Copying run_puppet.bash to /usr/local/bin."
    cp $TMP_DIR/run_puppet.bash /usr/local/bin
    chown root:root /usr/local/bin/run_puppet.bash
    chmod 744 /usr/local/bin/run_puppet.bash
    
    echo "Moving $TMP_DIR/puppet to $NEW_DIR."
    if ! mv "$TMP_DIR/puppet" "$NEW_DIR"; then
        echo "Unable to move updated puppet configuration to $NEW_DIR." >&2
        exit 1
    fi
    
    echo "Linking $NEW_DIR to $PUPPET_LINK."
    if ! ln -sfn "$NEW_DIR" "$PUPPET_LINK"; then
        echo "Link attempt failed." >&2
        rm -r "$NEW_DIR"
        exit 1
    fi
    
    if [[ -d "$CURRENT_PUPPET_DIR" ]]; then
        echo "Removing old puppet export $CURRENT_PUPPET_DIR."
        rm -r "$CURRENT_PUPPET_DIR"
    fi
fi

puppet apply $PUPPET_DEBUG --confdir "$PUPPET_LINK" "$PUPPET_LINK/manifests/init.pp"
