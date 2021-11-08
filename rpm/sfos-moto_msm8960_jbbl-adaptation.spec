Name:       sfos-moto_msm8960_jbbl-adaptation
Summary:    Bunch of dirty hacks for moto_msm8960_jbbl
Version:    0.1.8
Release:    1
Group:      Qt/Qt
License:    LICENSE
URL:        http://example.org/
Source0:    %{name}-%{version}.tar.bz2
Requires:   patch
Requires:   droid-hal-moto_msm8960_jbbl
Requires:   sailfish-version >= 3.4.0
Requires:   createrepo_c

%description
Bunch of dirty hacks for moto_msm8960_jbbl


%prep
%setup -q -n %{name}-%{version}


%build


%install
rm -rf %{buildroot}
mkdir -p %{buildroot}%{_datadir}/%{name}/patches
mkdir -p %{buildroot}%{_datadir}/%{name}/sparse
mkdir -p %{buildroot}%{_datadir}/ssu/features.d/
install -m 744 upgrade.sh %{buildroot}%{_datadir}/%{name}/
install -m 744 real-upgrade.sh %{buildroot}%{_datadir}/%{name}/
install -m 644 patches/jolla-camera.patch %{buildroot}%{_datadir}/%{name}/patches/
install -m 644 elros34-sailfishapps.ini %{buildroot}%{_datadir}/ssu/features.d/
cp -r xkb/ %{buildroot}%{_datadir}/%{name}/

%clean
rm -rf %{buildroot}

%triggerin -- jolla-sessions-qt5
if grep -q defaultuser "/usr/lib/startup/start-autologin"; then
    echo "Replacing defaultuser with nemo in: /usr/lib/startup/start-autologin"
    sed -i 's|defaultuser|nemo|g' /usr/lib/startup/start-autologin || true
fi

%triggerin -- xkeyboard-config
echo "Overwritting hw keyboard layout!"
/bin/cp -rf /usr/share/sfos-moto_msm8960_jbbl-adaptation/xkb/* /usr/share/X11/xkb/


%triggerin -- jolla-camera
CAMERA_DIR="/usr/lib/qt5/qml/com/jolla/camera/capture"
if ! grep -q initialMediaKeysEnabled "$CAMERA_DIR/CaptureView.qml"; then
    PKG_DIR="/usr/share/sfos-moto_msm8960_jbbl-adaptation"
    echo "Patching jolla-camera: CaptureView.qml and CaptureOverlay.qml"
    /bin/cp -f $CAMERA_DIR/{CaptureOverlay.qml,CaptureView.qml} $PKG_DIR/backup/
    patch -f -p0 -d/ < $PKG_DIR/patches/jolla-camera.patch || true
fi

%files
%defattr(-,root,root,-)
%attr(744,root,root) %{_datadir}/%{name}/*.sh
%attr(644,root,root) %{_datadir}/%{name}/patches/
%attr(644,root,root) %{_datadir}/%{name}/xkb/
%attr(644,root,root) %{_datadir}/ssu/features.d/*


