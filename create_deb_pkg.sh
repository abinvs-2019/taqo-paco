#!/bin/bash

if [ -z ${FLUTTER_SDK} ]; then
  echo "Must set FLUTTER_SDK"
  exit 1
fi

if [ -z ${DART_SDK} ]; then
  echo "Must set DART_SDK"
  exit 1
fi

# Build flutter app
pushd taqo_client || exit
${FLUTTER_SDK}/bin/flutter clean && ${FLUTTER_SDK}/bin/flutter build linux
popd || exit

# Build PAL event server / linux daemon
${DART_SDK}/bin/dart2native -p pal_event_server/.packages \
  -o taqo_client/build/linux/release/taqo_daemon \
  pal_event_server/lib/main.dart

PKG=taqosurvey
VER=1.0-1
ARCH=amd64
DEB=${PKG}_${VER}_${ARCH}

BUILD=taqo_client/build/linux
#DEBUG=${BUILD}/debug
RELEASE=${BUILD}/release
OUT=${BUILD}/${DEB}

rm -rf ${OUT}

mkdir -p ${OUT}/usr/share/taqo
cp -R ${RELEASE}/data ${OUT}/usr/share/taqo/
cp ${RELEASE}/taqo ${OUT}/usr/share/taqo/
cp ${RELEASE}/taqo_daemon ${OUT}/usr/share/taqo/
# Ideally the binaries would go here, but the flutter linux embedder
# currently expects the resources to be located in a relative path
# (and there is no way to pass runtime args to the embedder)
#mkdir -p ${OUT}/usr/bin
#cp ${RELEASE}/taqo ${OUT}/usr/bin/
#cp ${RELEASE}/taqo_daemon ${OUT}/usr/bin/
mkdir -p ${OUT}/usr/lib
cp ${RELEASE}/lib/* ${OUT}/usr/lib/

find ${OUT}/usr/share/taqo/data -type f -exec chmod 0644 {} \;
chmod 0755 ${OUT}/usr/share/taqo/taqo
chmod 0755 ${OUT}/usr/share/taqo/taqo_daemon
chmod 0644 ${OUT}/usr/lib/*

# dpkg-deb complains about non-stripped binaries, but stripping
# breaks them
#strip ${OUT}/usr/bin/taqo
#strip ${OUT}/usr/bin/taqo_daemon
#strip ${OUT}/usr/lib/*

mkdir -p ${OUT}/usr/share/applications
touch ${OUT}/usr/share/applications/taqo.desktop
chmod 0644 ${OUT}/usr/share/applications/taqo.desktop
cat > ${OUT}/usr/share/applications/taqo.desktop <<- EOM
[Desktop Entry]
Name=Taqo Survey
Comment=Taqo user study survey app
Exec=taqo
Terminal=false
Type=Application
#StartupNotify=true
Icon=/usr/share/taqo/data/flutter_assets/assets/paco256.png
Categories=GNOME;GTK;Utility;TextEditor;
#Actions=new-window
Keywords=Taqo;taqo;survey
#DBusActivatable=true

#[Desktop Action new-window]
#Name=New Window
#Exec=gedit --new-window
EOM

touch ${OUT}/usr/share/applications/taqo_daemon.desktop
chmod 0644 ${OUT}/usr/share/applications/taqo_daemon.desktop
cat > ${OUT}/usr/share/applications/taqo_daemon.desktop <<- EOM
[Desktop Entry]
Name=Taqo Daemon
Comment=Taqo user study survey app
Exec=taqo_daemon
Terminal=true
Type=Application
Icon=/usr/share/taqo/data/flutter_assets/assets/paco256.png
Categories=GNOME;GTK;Utility;TextEditor;
Keywords=Taqo;taqo;survey
EOM

mkdir -p ${OUT}/DEBIAN
touch ${OUT}/DEBIAN/control
cat > ${OUT}/DEBIAN/control <<- EOM
Package: taqosurvey
Version: 1.0-1
Architecture: ${ARCH}
Maintainer: Bob Evans <bobevans@google.com>
Section: devel
Priority: optional
Homepage: https://pacoapp.com/
Pre-Depends: libc6, libsqlite3-dev
Description: Taqo survey app
 Long description goes here.
EOM

mkdir -p ${OUT}/DEBIAN
touch ${OUT}/DEBIAN/triggers
cat > ${OUT}/DEBIAN/triggers <<- EOM
activate-noawait ldconfig
EOM

touch ${OUT}/DEBIAN/postinst
chmod 0755 ${OUT}/DEBIAN/postinst
cat > ${OUT}/DEBIAN/postinst <<- EOM
#!/bin/bash
ln -s /usr/share/taqo/taqo /usr/bin/taqo
ln -s /usr/share/taqo/taqo_daemon /usr/bin/taqo_daemon
# Auto launch the daemon
mkdir -p /etc/xdg/autostart
cp /usr/share/applications/taqo_daemon.desktop /etc/xdg/autostart/
EOM

find ${OUT} -type d -exec chmod 0755 {} \;
fakeroot dpkg-deb --build ${OUT}
lintian --no-tag-display-limit ${OUT}.deb