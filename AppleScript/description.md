
This script exports your mails into eml format from your Outlook app.

There are four things you need to set:
- Start date
- End date
- Outlook folder
- Export folder

Obviously the dates describe a time window where the export is allowed. I'm using this not to export fresh emails since I use them very often to protect my butt (who-sent-what flame wars, etc, usual office stuff). Note, the script does not delete the mails in Outlook!

Outlook folder is a simple name for your source folder, the script does not handle multiple instances, first match wins if you have multiple folders with the same name. Also, subfolders are not handled.

Export folder is a local directory path, I'm using absolute path. Note, the final export folder will be a concatenation of the export folder + the source folder name. The script does not create the export folder, it must exists before you run the script.

Export file name convention is: xxxxx_yyyymmdd_hhmiss_sendername.eml You can edit this with editing the "set theFileName to " line to whatever you need. The date in the file name is the sending date of the mail, while xxxxx is an integer, starting from 00001 to 99999.

I tested the script with folders up to 6000 mails without any problem. If you have larger folders, please take care of the xxxxx field during the export, it might be small after 99999 mails. (I would be interested if someone have mail folders over 100k mails).

One more thing, yes, it takes a while to process large folders. Outlook might be unaccessible while the script maps the mails in the folder, during the export you can reach your mails again.
