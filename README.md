# Plexus docker container


Building the container:
  docker build -t plexus_gpu .
 
To run launch the container
  nvidia-docker run -ti --rm plexus_gpu
