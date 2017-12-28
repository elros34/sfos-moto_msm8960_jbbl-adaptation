Name:       sfos-moto_msm8960_jbbl-adaptation
Summary:    Bunch of dirty hacks for moto_msm8960_jbbl
Version:    0.0.1
Release:    1
Group:      Qt/Qt
License:    LICENSE
URL:        http://example.org/
Source0:    %{name}-%{version}.tar.bz2
Requires:   patch
Requires:   droid-hal-moto_msm8960_jbbl

%description
Bunch of dirty hacks for moto_msm8960_jbbl


%prep
%setup -q -n %{name}-%{version}


%build


%install
rm -rf %{buildroot}
mkdir -p %{buildroot}%{_datadir}/%{name}/patches
mkdir -p %{buildroot}%{_datadir}/%{name}/sparse
install -m 755 moto_msm8960_jbbl.sh %{buildroot}%{_datadir}/%{name}/
install -m 644 patches/jolla-camera.patch %{buildroot}%{_datadir}/%{name}/patches/
cp -r sparse/ %{buildroot}%{_datadir}/%{name}/

%clean
rm -rf %{buildroot}

%post
#echo "execute moto_msm8960_jbbl.sh"
#%{_datadir}/%{name}/moto_msm8960_jbbl.sh


%files
%attr(755,root,root) %{_datadir}/%{name}/moto_msm8960_jbbl.sh
%attr(644,root,root) %{_datadir}/%{name}/patches/
%attr(644,root,root) %{_datadir}/%{name}/sparse/

