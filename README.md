# wptagent-docker
**THIS IS SUPER SUPER WIP AND DOESN'T WORK! Please do check back later though** :)

Run the Webpage Test Agent from inside a Docker image, using runtime configuration

## Build

Use a local Docker daemon to construct the image:

```
# Change MAKE_ARCH=x86_64 to MAKE_ARCH=armel for building directly on Pi ARM CPU (haven't figured out cross-compiler yet!)
docker build -t jack/testing --build-arg MAKE_ARCH=x86_64 --build-arg AGENT_MODE=Android --build-arg DISABLE_IPV6=y --build-arg WPT_SERVER=localhost:8080 --build-arg WPT_LOCATION=london .
```
