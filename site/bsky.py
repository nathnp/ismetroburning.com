import sys
import os
from dotenv import load_dotenv
from atproto import Client

load_dotenv()

handle = os.getenv("HANDLE")
app_password = os.getenv("BSKY_KEY")

text = sys.argv[1]  # get the message from the first argument

client = Client()
client.login(handle, app_password)
client.send_post(text)
