# SecureBackup

This small Bash script will backup and encrypt files, or decrypt and recover files.

For encryption and decryption, **GnuPG** is used. The cipher algorithm is **AES-256**. No compression is performed.

# Usage

    Usage: ./backup [-h] [-o OUTPUT] -b|-r [FILE1 FILE2 ...]
      -h              Output this message.

      -o OUTPUT       In backup mode, this means the name of the output file
                      and is, by default, "data_backup.tar.gpg".
                      In recover mode, this means the directory where files are
                      output and is, by default, the present working directory.

      -b              Backup files and encrypt.

      -r              Decrypt and recover files.

Backup mode takes multiple files and gives a single encrypted blob.
Recover mode takes multiple files and decrypts each one respectively.

If input files are not given, this implies that input files are in the
      directory from where the script is being called, i.e., the present directory.

## Examples

    $ ./backup.bash -b

Backup and encrypt all of the files in the present working directory and output the result into *data_backup.tar.gpg*.

    $ ./backup.bash -r *.bak

Decrypt and recover the contents of files ending in *\*.bak* and place them in the present working directory.

    $ ./backup.bash -bo repo/mybackup foo bar baz

Backup and encrypt files *foo*, *bar*, and *baz* and output the result into *repo/mybackup.tar.gpg*.

    $ ./backup.bash -ro documents repo/mybackup.tar.gpg

Decrypt and recover contents inside *repo/mybackup.tar.gpg* and place them in directory *documents*.
