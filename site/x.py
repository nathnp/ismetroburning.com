import sys
import tweepy
import os
from dotenv import load_dotenv

load_dotenv()

# Replace these with your actual Twitter API credentials
API_KEY = os.getenv("X_API_KEY")
API_KEY_SECRET = os.getenv("X_API_KEY_SECRET")
ACCESS_TOKEN = os.getenv("X_ACCESS_TOKEN")
ACCESS_TOKEN_SECRET = os.getenv("X_ACCESS_TOKEN_SECRET")
BEARER_TOKEN = os.getenv("X_BEARER_TOKEN")

# Authenticate with Twitter API using Tweepy
client = tweepy.Client(
    bearer_token=BEARER_TOKEN,
    consumer_key=API_KEY,
    consumer_secret=API_KEY_SECRET,
    access_token=ACCESS_TOKEN,
    access_token_secret=ACCESS_TOKEN_SECRET
)

# Post a tweet
tweet_text = sys.argv[1]
try:
    response = client.create_tweet(text=tweet_text)
    print("Tweet posted successfully!", response)
except Exception as e:
    print("Error posting tweet:", e)
