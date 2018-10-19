FROM fredhutch/ls2_easybuild_toolchain:foss-2018b

# Remember the default use is LS2_USERNAME, not root

# DEPLOY_PREFIX comes from ls2_lmod container, two containers up!

# easyconfig to build - leave '.eb' off
ARG EB_NAME
ENV EB_NAME=${EB_NAME}

# libibverbs required for foss toolchains
ENV INSTALL_OS_PKGS ""

# os pkg list to be removed after the build - in EasyBuild, the 'dummy' toolchain requires build-essential
# also, the current toolchain we are using (foss-2016b) does not actually include 'make'
# removing build-essential will mean the resulting container cannot build additional software
ENV UNINSTALL_OS_PKGS ""

# copy install and deploy scripts in
COPY install.sh /ls2/
COPY deploy.sh /ls2/
COPY sources/download_sources.sh /ls2/
COPY easyconfigs/* /app/fh_easyconfigs/
COPY sources/* /app/sources/
RUN /bin/bash /ls2/download_sources.sh

# install and uninstall build-essential in one step to reduce layer size
# while installing Lmod, again must be root
USER root
RUN DEBIAN_FRONTEND=noninteractive \
    apt-get update -y \
    && apt-get install -y ${INSTALL_OS_PKGS} \
    && su -c "/bin/bash /ls2/install.sh" ${LS2_USERNAME} \
    && AUTO_ADDED_PKGS=$(apt-mark showauto) apt-get remove -y --purge ${UNINSTALL_OS_PKGS} ${AUTO_ADDED_PKGS} \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*

# gather installed pkgs list
RUN dpkg -l > /ls2/installed_pkgs.${EB_NAME}

# switch to LS2 user for future actions
USER ${LS2_USERNAME}
WORKDIR /home/${LS2_USERNAME}
SHELL ["/bin/bash", "-c"]

