#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Trip Planner Microservice Deployment Script for Render.com ===${NC}"
echo "This script will deploy the Trip Planner microservice to Render.com"

# Check for required tools
echo -e "\n${YELLOW}Checking prerequisites...${NC}"

# Check for curl
if ! command -v curl &> /dev/null; then
    echo -e "${RED}curl is not installed. Please install curl first.${NC}"
    exit 1
fi

# Check for jq (for JSON parsing)
if ! command -v jq &> /dev/null; then
    echo -e "${YELLOW}jq is not installed. Installing jq...${NC}"
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        sudo apt-get update && sudo apt-get install -y jq
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        brew install jq
    else
        echo -e "${RED}Could not install jq automatically. Please install jq manually.${NC}"
        echo "Visit https://stedolan.github.io/jq/download/ for instructions."
        exit 1
    fi
fi

# Check for git
if ! command -v git &> /dev/null; then
    echo -e "${RED}git is not installed. Please install git first.${NC}"
    echo "Visit https://git-scm.com/ to download and install."
    exit 1
fi

echo -e "${GREEN}All prerequisites are installed.${NC}"

# Prompt for API keys
echo -e "\n${YELLOW}Setting up environment variables...${NC}"
read -p "Enter your WeatherBit API key (or press Enter to use mock data): " WEATHERBIT_API_KEY
read -p "Enter your OpenAI API key (or press Enter to use mock data): " OPENAI_API_KEY

# Set default to use mock data if no API keys provided
USE_MOCK_DATA="false"
if [ -z "$WEATHERBIT_API_KEY" ] || [ -z "$OPENAI_API_KEY" ]; then
    USE_MOCK_DATA="true"
    echo -e "${YELLOW}No API keys provided. Using mock data.${NC}"
fi

# Create a temporary directory for deployment
TEMP_DIR=$(mktemp -d)
echo -e "\n${YELLOW}Creating temporary directory for deployment: ${TEMP_DIR}${NC}"

# Clone the trip planner code to the temporary directory
echo -e "\n${YELLOW}Copying Trip Planner code...${NC}"
cp -r trip-planner/* $TEMP_DIR/
cd $TEMP_DIR

# Create necessary directories for data
mkdir -p app/data

# Create empty mock data files
echo -e "\n${YELLOW}Creating initial data files...${NC}"
echo "{}" > app/data/mock_weather_data.json
echo "{}" > app/data/mock_accommodations.json
echo "{}" > app/data/mock_equipment.json
echo "{}" > app/data/mock_embeddings_cache.json
echo "[]" > app/data/destination_embeddings.json

# Create render.yaml configuration file
echo -e "\n${YELLOW}Creating Render configuration file...${NC}"
cat > render.yaml << EOL
services:
  - type: web
    name: trip-planner
    env: python
    buildCommand: pip install -r requirements.txt
    startCommand: uvicorn app.main:app --host 0.0.0.0 --port \$PORT
    envVars:
      - key: WEATHERBIT_API_KEY
        value: ${WEATHERBIT_API_KEY}
      - key: OPENAI_API_KEY
        value: ${OPENAI_API_KEY}
      - key: USE_MOCK_DATA
        value: ${USE_MOCK_DATA}
      - key: API_HOST
        value: 0.0.0.0
      - key: API_PORT
        sync: false
EOL

# Create a new git repository
echo -e "\n${YELLOW}Initializing git repository...${NC}"
git init
git add .
git commit -m "Initial commit for Render deployment"

# Prompt for GitHub repository creation
echo -e "\n${YELLOW}To deploy to Render, we need to push this code to a GitHub repository.${NC}"
read -p "Enter your GitHub username: " GITHUB_USERNAME
read -p "Enter a name for your new GitHub repository: " REPO_NAME

# Create GitHub repository
echo -e "\n${YELLOW}Creating GitHub repository...${NC}"
read -p "Enter your GitHub personal access token (with repo permissions): " GITHUB_TOKEN

# Create repository on GitHub
REPO_CREATION_RESPONSE=$(curl -s -X POST \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  https://api.github.com/user/repos \
  -d "{\"name\":\"$REPO_NAME\",\"private\":true}")

# Check if repository was created successfully
if echo "$REPO_CREATION_RESPONSE" | grep -q "Bad credentials"; then
    echo -e "${RED}Failed to create GitHub repository. Invalid GitHub token.${NC}"
    exit 1
fi

if echo "$REPO_CREATION_RESPONSE" | grep -q "name already exists"; then
    echo -e "${YELLOW}Repository already exists. Continuing with existing repository.${NC}"
else
    echo -e "${GREEN}GitHub repository created successfully.${NC}"
fi

# Add GitHub remote
echo -e "\n${YELLOW}Adding GitHub remote...${NC}"
git remote add origin "https://$GITHUB_USERNAME:$GITHUB_TOKEN@github.com/$GITHUB_USERNAME/$REPO_NAME.git"
git push -u origin master || git push -u origin main

echo -e "${GREEN}Code pushed to GitHub repository.${NC}"

# Instructions for Render deployment
echo -e "\n${GREEN}=== Next Steps for Render Deployment ===${NC}"
echo -e "1. Go to https://dashboard.render.com/select-repo?type=web"
echo -e "2. Connect your GitHub account if you haven't already"
echo -e "3. Select the '$REPO_NAME' repository"
echo -e "4. Render will automatically detect the render.yaml configuration"
echo -e "5. Click 'Apply' to deploy the service"
echo -e "6. Once deployed, copy the URL provided by Render"

# Clean up
echo -e "\n${YELLOW}Cleaning up temporary files...${NC}"
cd -
rm -rf $TEMP_DIR
echo -e "${GREEN}Cleanup complete.${NC}"

echo -e "\n${GREEN}=== Final Steps ===${NC}"
echo -e "1. Add the following environment variable to your Next.js application:"
echo -e "   ${YELLOW}TRIP_PLANNER_URL=https://trip-planner.onrender.com${NC}"
echo -e "   (Replace with your actual Render URL once deployed)"
echo -e "2. Restart your Next.js application"
echo -e "3. Access the Trip Planner at /trip-planner in your application"
echo -e "\n${GREEN}Setup complete! Follow the steps above to finish deployment.${NC}"