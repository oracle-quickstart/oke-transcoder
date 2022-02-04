import sys
from werkzeug.security import generate_password_hash; 
if len (sys.argv) < 2:
  print("Error: Usage {} <password>".format(sys.argv[0]))
  exit (1)
print(generate_password_hash(sys.argv[1], method='sha256'))