FROM debian:stretch

# Install dependencies
RUN apt update && \
    apt install -y curl && \
    apt clean && \
    apt clean cache  # Is this needed?

# Setup environment
RUN useradd -d /opt/wptagent -m -u 1001 wptagent
ARG AGENT_MODE
ARG DISABLE_IPV6
ARG WPT_SERVER
ARG WPT_LOCATION
ARG WPT_KEY
ARG WPT_DEVICE_NAME
ARG MAKE_ARCH

# Copy run installer for Raspbian Buster
COPY container-install.sh ./
RUN ARG_MAKE_ARCH=${MAKE_ARCH} ARG_AGENT_MODE=${AGENT_MODE} DISABLE_IPV6=${DISABLE_IPV6} WPT_SERVER=${WPT_SERVER} ./raspbian.sh

# Move to wptagent context
USER wptagent
WORKDIR /opt/wptagent

# Set CMD
COPY entrypoint.sh ./
ENTRYPOINT entrypoint.sh