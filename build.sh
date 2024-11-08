#!/bin/sh
docker run --rm -it --tty \
    --volume "$(pwd)/main:/home/packager/main" \
    --volume "$(pwd)/packages:/home/packager/packages" \
    alpine:3.20 sh -c "
        set -eux
        apk add sudo build-base alpine-sdk
        adduser -D packager
        addgroup packager abuild
        echo 'packager ALL=(ALL) NOPASSWD:ALL' \
        >/etc/sudoers.d/packager
        # then open an sh as packager user
        sudo -u packager sh -c '
            abuild-keygen -n --append --install
            # build all packages
            cd /home/packager
            repos="main"
            for repo in \$repos; do
                cd /home/packager/\$repo
                mkdir -p /home/packager/packages/\$repo
                pkgs=\$(ls)
                for pkg in \$pkgs; do
                    cd /home/packager/\$repo/\$pkg
                    abuild checksum
                    REPODEST=/home/packager/packages abuild -r
                done
            done
        '
    "