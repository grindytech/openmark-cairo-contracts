######## CREATE ACCOUNT ########

sncast --url https://free-rpc.nethermind.io/sepolia-juno/v0_7 account add --name ${} --address ${} --type argent --private-key ${} --add-profile ${}

#### DECLARE OPENMARK
sncast --account admin declare --url https://starknet-sepolia.public.blastapi.io/rpc/v0_7 --contract-name OpenMark --fee-token strk

## DECLARE OPEN COLLECTION
sncast --account admin declare --url https://starknet-sepolia.public.blastapi.io/rpc/v0_7 --contract-name OpenCollection --fee-token strk

## DECLARE OPEN LAUNCHPAD
sncast --account admin declare --url https://starknet-sepolia.public.blastapi.io/rpc/v0_7 --contract-name OpenLaunchpad --fee-token strk

## DECLARE OERC721 FACTORY
sncast --account admin declare --url https://starknet-sepolia.public.blastapi.io/rpc/v0_7 --contract-name OERC721Factory --fee-token strk

## DECLARE OERC1155 FACTORY
sncast --account admin declare --url https://starknet-sepolia.public.blastapi.io/rpc/v0_7 --contract-name OERC1155Factory --fee-token strk

## DECLARE LAUNCHPAD FACTORY
sncast --account admin declare --url https://starknet-sepolia.public.blastapi.io/rpc/v0_7 --contract-name LaunchpadFactory --fee-token strk

######################## STAGES

## DECLARE StageSelector
sncast --account admin declare --url https://starknet-sepolia.public.blastapi.io/rpc/v0_7 --contract-name StageSelector --fee-token strk

## DECLARE StageBatchSelector
sncast --account admin declare --url https://starknet-sepolia.public.blastapi.io/rpc/v0_7 --contract-name StageBatchSelector --fee-token strk


######################## COLLECTIONS

## DECLARE OERC721
sncast --account admin declare --url https://starknet-sepolia.public.blastapi.io/rpc/v0_7 --contract-name OERC721 --fee-token strk

## DECLARE OERC1155
sncast --account admin declare --url https://starknet-sepolia.public.blastapi.io/rpc/v0_7 --contract-name OERC1155 --fee-token strk

## DECLARE LAUNCHPAD
sncast --account admin declare --url https://starknet-sepolia.public.blastapi.io/rpc/v0_7 --contract-name Launchpad --fee-token strk