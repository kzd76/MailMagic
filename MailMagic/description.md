
This is the Swift part to record mail information in an SQLite database.

Processing quoted printable texts are processed based on the work of Johannes Schriewer (https://github.com/dunkelstern/QuotedPrintable)

StreamReader was found at https://gist.github.com/klgraham.

Functions from command line:
- -d: path to the database file. By default it will be created into the execution directory
- -c: create the tables. By default if the tables are not existing it will not be created automatically
- -p: path to email files. Subdirectories are processed.
- -f: find one word in database. It will be searched trough the from, to, subject fields and the mail body
- -fw: find mails based on a where clausa. E.g. -fw "where mailfrom like '%zzz%' and mailsubject like '%kkk%'"
- -g: get mail content based on the file name

