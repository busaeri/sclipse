menimpan ke ethereum_private_key.txt
 node bin/cli.js -k "$ethereum_private_key"
#!/bin/bash

export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export NC='\033[0m'

prompt() {
    local message="$1"
    read -p "$message" input
    echo "$input"
}

execute_and_prompt() {
    local message="$1"
    local command="$2"
    echo -e "${YELLOW}${message}${NC}"
    eval "$command"
    echo -e "${GREEN}Done.${NC}"
}

# Install Rust
echo -e "${YELLOW}Installing Rust...${NC}"
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
source "$HOME/.cargo/env"
echo -e "${GREEN}Rust installed: $(rustc --version)${NC}"
echo

# Remove existing Node.js
echo -e "${YELLOW}Removing Node.js...${NC}"
sudo apt-get remove -y nodejs
echo

# Install Node.js LTS directly
echo -e "${YELLOW}Installing Node.js LTS...${NC}"
curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
sudo apt-get install -y nodejs
echo -e "${GREEN}Node.js installed: $(node -v)${NC}"
echo

# Install Yarn globally using sudo
echo -e "${YELLOW}Installing Yarn...${NC}"
sudo npm install -g yarn
echo -e "${GREEN}Yarn installed: $(yarn -v)${NC}"
echo

# Cloning repository and installing npm dependencies
echo -e "${YELLOW}Cloning repository and installing npm dependencies...${NC}"
git clone https://github.com/Eclipse-Laboratories-Inc/eclipse-deposit.git
cd eclipse-deposit

# Clear Yarn cache
yarn cache clean

# Install dependencies with verbose output
echo -e "${YELLOW}Installing dependencies with Yarn (verbose mode)...${NC}"
yarn install --verbose
echo

# Install Solana CLI
echo -e "${YELLOW}Installing Solana CLI...${NC}"
sh -c "$(curl -sSfL https://release.solana.com/stable/install)"
export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"
echo -e "${GREEN}Solana CLI installed: $(solana --version)${NC}"
echo

# Generating new Solana keypair
echo -e "${YELLOW}Generating new Solana keypair...${NC}"
solana-keygen new -o ~/my-wallet.json
echo
echo -e "${YELLOW}Save these mnemonic phrases in a safe place. If there will be any airdrop in the future, you will be eligible from this wallet so save it.${NC}"
echo

mnemonic=$(prompt "Enter your mnemonic phrase: ")
echo

cat << EOF > secrets.json
{
  "seedPhrase": "$mnemonic"
}
EOF

cat << 'EOF' > derive-wallet.js
const { seedPhrase } = require('./secrets.json');
const { HDNodeWallet } = require('ethers');

const mnemonicWallet = HDNodeWallet.fromPhrase(seedPhrase);
console.log();
console.log('ETHEREUM PRIVATE KEY:', mnemonicWallet.privateKey);
console.log();
console.log('SEND SEPOLIA ETH TO THIS ADDRESS:', mnemonicWallet.address);
EOF

if ! npm list ethers &>/dev/null; then
  echo "ethers.js not found. Installing..."
  npm install ethers
  echo
fi

node derive-wallet.js
echo

# Configuring Solana CLI
echo -e "${YELLOW}Configuring Solana CLI...${NC}"
solana config set --url https://testnet.dev2.eclipsenetwork.xyz
solana config set --keypair ~/my-wallet.json
echo -e "${GREEN}Solana Address: $(solana address)${NC}"
echo

# Removing eclipse-deposit Folder if it exists
if [ -d "eclipse-deposit" ]; then
    execute_and_prompt "Removing eclipse-deposit Folder..." "rm -rf eclipse-deposit"
fi

solana_address=$(prompt "Enter your Solana address: ")
ethereum_private_key=$(prompt "Enter your Ethereum Private Key: ")
repeat_count=$(prompt "Enter the number of times to repeat Transaction (4-5 tx Recommended): ")
gas_limit="4000000"
echo

for ((i=1; i<=repeat_count; i++)); do
    echo -e "${YELLOW}Running Bridge Script (Tx $i)...${NC}"
    node bin/cli.js -k "$ethereum_private_key" -d "$solana_address" -a 0.002 --sepolia
    echo
    sleep 3
done

echo -e "${RED}It will take 4 mins, Don't do anything, Just Wait${NC}"
sleep 240

execute_and_prompt "Creating token..." "spl-token create-token --enable-metadata -p TokenzQdBNbLqP5VEhdkAS6EPFLC1PHnBqCXEpPxuEb"
echo

token_address=$(prompt "Enter your Token Address: ")
echo
execute_and_prompt "Creating token account..." "spl-token create-account $token_address"
echo

execute_and_prompt "Minting token..." "spl-token mint $token_address 10000"
echo
execute_and_prompt "Checking token accounts..." "spl-token accounts"
echo

execute_and_prompt "Checking Program Address..." "solana address"
echo
