Name:       ru.omstu.STT
Summary:    Моё приложения для ОС Аврора
Version:    0.3
Release:    1
License:    BSD-3-Clause
URL:        https://auroraos.ru
Source0:    %{name}-%{version}.tar.bz2

Requires:   sailfishsilica-qt5 >= 0.10.9

%define _missing_build_ids_terminate_build 0
%define _unpackaged_files_terminate_build 0

# libvosk.so и libatomic.so.1 — приватные библиотеки, лежащие ВНУТРИ пакета
# (в /usr/share/ru.omstu.STT/lib). Валидатор Авроры запрещает пакету и
# экспортировать их как системный Provides, и требовать их как внешние
# зависимости. Поэтому исключаем авто-Provides для файлов из нашего lib-каталога
# и авто-Requires на сырые soname libvosk.so / libatomic.so.1.
%define __provides_exclude_from ^%{_datadir}/%{name}/lib/.*\.so.*$
%define __requires_exclude ^lib(vosk|atomic)\.so.*$

BuildRequires:  pkgconfig(auroraapp)
BuildRequires:  pkgconfig(Qt5Core)
BuildRequires:  pkgconfig(Qt5Qml)
BuildRequires:  pkgconfig(Qt5Quick)
BuildRequires:  pkgconfig(Qt5Multimedia)

%description
Короткое описание моего приложения для ОС Аврора

%prep
%autosetup

%build
%qmake5
%make_build

%install
%make_install
install -D -m 644 %{_sourcedir}/vosk/sailjail/%{name}.conf %{buildroot}%{_datadir}/sailjail/config/%{name}.conf

%files
%defattr(-,root,root,-)
%{_bindir}/%{name}
%defattr(644,root,root,-)
%{_datadir}/%{name}
%{_datadir}/applications/%{name}.desktop
%{_datadir}/icons/hicolor/86x86/apps/%{name}.png
%{_datadir}/icons/hicolor/108x108/apps/%{name}.png
%{_datadir}/icons/hicolor/128x128/apps/%{name}.png
%{_datadir}/icons/hicolor/172x172/apps/%{name}.png
%{_datadir}/sailjail/config/%{name}.conf
