#!/bin/bash

# run nginx and reload periodically in order to update cert if necessary
nginx && sleep 120s && while [ true ] ; do nginx -s reload ; sleep 62m ; done ;
