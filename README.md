# Plexus docker container


## Building the container:

> docker build -t plexus_gpu:latest .
 
## To run launch the container

> nvidia-docker run -ti --rm plexus_gpu:latest

Note: _plexus_gpu:latest_ is the string used to tag the built image, but any other tag may be used
