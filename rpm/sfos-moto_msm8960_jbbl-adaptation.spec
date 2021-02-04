Name:       sfos-moto_msm8960_jbbl-adaptation
Summary:    Bunch of dirty hacks for moto_msm8960_jbbl
Version:    0.1.3
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
install -m 744 moto_msm8960_jbbl.sh %{buildroot}%{_datadir}/%{name}/
install -m 744 upgrade.sh %{buildroot}%{_datadir}/%{name}/
install -m 744 real-upgrade.sh %{buildroot}%{_datadir}/%{name}/
install -m 644 patches/jolla-camera.patch %{buildroot}%{_datadir}/%{name}/patches/
install -m 644 elros34-sailfishapps.ini %{buildroot}%{_datadir}/ssu/features.d/
cp -r sparse/ %{buildroot}%{_datadir}/%{name}/

%clean
rm -rf %{buildroot}



%files
%defattr(-,root,root,-)
%attr(744,root,root) %{_datadir}/%{name}/*.sh
%attr(644,root,root) %{_datadir}/%{name}/patches/
%attr(644,root,root) %{_datadir}/%{name}/sparse/
%attr(644,root,root) %{_datadir}/ssu/features.d/*


