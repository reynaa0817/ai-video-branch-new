FROM mysql@sha256:c831a0f11348d402b43d77453e17d770be2eef356615a2823fe0f5a0d6c8b9af

RUN rpm -e --nodeps mysql-community-server-minimal \
    && printf '[mysql8.4-community]\nname=MySQL 8.4 Community\nenabled=1\nbaseurl=https://repo.mysql.com/yum/mysql-8.4-community/el/9/$basearch/\ngpgcheck=1\ngpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-mysql\nmodule_hotfixes=true\n' >/etc/yum.repos.d/mysql-community.repo \
    && microdnf install -y mysql-community-client-8.4.10-1.el9 \
    && microdnf clean all \
    && mysqlbinlog --version

ENTRYPOINT ["/bin/sh"]
