#!/bin/sh
ALPINE=3.20
docker run --rm -it --tty \
    --volume "$(pwd)/main:/home/packager/main" \
    --volume "$(pwd)/packages:/home/packager/packages" \
    alpine:$ALPINE sh -c "
        set -eux
        apk add sudo build-base alpine-sdk
        adduser -D packager
        addgroup packager abuild
        echo 'packager ALL=(ALL) NOPASSWD:ALL' \
        >/etc/sudoers.d/packager
        # then open an sh as packager user
        sudo -u packager sh -c '
            #abuild-keygen -a -i
            abuild-keygen -n --append --install
            # build all packages
            cd /home/packager
            repos="main"
            for repo in \$repos; do
                cd /home/packager/\$repo
                rm /home/packager/packages/\$repo/\$(uname -m)/*
                pkgs=\$(ls)
                for pkg in \$pkgs; do
                    case \$pkg in
                        # incus-next) continue ;;
                        # incus-feature) continue ;;
                        # incus-ui) continue ;;
                        *) ;;
                    esac
                    cd /home/packager/\$repo/\$pkg
                    abuild checksum
                    REPODEST=/home/packager/packages abuild -r
                done
            done
        '
    "