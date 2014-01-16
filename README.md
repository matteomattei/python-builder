python-builder
==============

A bash script to build Python inside Ubuntu and put it in the folder you want.

    Usage: ./python-builder.sh [-d <destination>] [-b <branch>] [-v <version>] [-l]

    -d <destination> | Mandatory: where destination is the folder containing the final bundle
    -b <branch>      | Mandatory: where branch is the name of the directory as reported in http://python.org/ftp/python
    -v <version>     | Mandatory: where version is the name of the version as reported in http://python.org/ftp/python
    -l               | Optional: Build links of generated binaries

    Example: ./python-builder.sh -d /opt -b 3.4.0 -v 3.4.0b2 -l
