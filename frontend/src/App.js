import { useWeb3React, Web3ReactProvider } from '@web3-react/core';
import { Web3Provider } from '@ethersproject/providers';
import { getAddress } from '@ethersproject/address';
import { AddressZero } from '@ethersproject/constants';
import { Contract } from '@ethersproject/contracts';
import { BigNumber } from 'ethers';
import { formatUnits, parseUnits } from 'ethers/lib/utils';
import { useEffect, useMemo, useState } from 'react';
import ReactHtmlParser from 'react-html-parser';
import {
    Badge,
    Box,
    Button,
    ChakraProvider,
    Container,
    Flex,
    Heading,
    HStack,
    Stat,
    StatLabel,
    StatNumber,
    Table,
    TableCaption,
    Tbody,
    Td,
    Text,
    Tr,
    VStack
} from '@chakra-ui/react';
import { DateTime } from 'luxon';


import { InjectedConnector } from '@web3-react/injected-connector';

import RedAavelopes from './RedAavelopes.json';

const injected = new InjectedConnector({supportedChainIds: [31337, 1, 3, 4, 5, 42]});

function getLibrary(provider, connector) {
    return new Web3Provider(provider); // this will vary according to whether you use e.g. ethers or web3.js
}

const abi = RedAavelopes.abi;

// returns the checksummed address if the address is valid, otherwise returns false
export function isAddress(value) {
    try {
        return getAddress(value);
    } catch {
        return false;
    }
}

// account is not optional
export function getSigner(library, account) {
    return library.getSigner(account).connectUnchecked();
}

// account is optional
export function getProviderOrSigner(library, account) {
    return account ? getSigner(library, account) : library;
}

// account is optional
export function getContract(address, ABI, library, account) {
    if (!isAddress(address) || address === AddressZero) {
        throw Error(`Invalid 'address' parameter '${address}'.`);
    }

    return new Contract(address, ABI, getProviderOrSigner(library, account));
}

export function useContract(
    addressOrAddressMap,
    ABI,
    withSignerIfPossible = true
) {
    const {library, account, chainId} = useWeb3React();

    return useMemo(() => {
        if (!addressOrAddressMap || !ABI || !library || !chainId) return null;
        let address;
        if (typeof addressOrAddressMap === 'string') address = addressOrAddressMap;
        else address = addressOrAddressMap[chainId];
        if (!address) return null;
        try {
            return getContract(address, ABI, library, withSignerIfPossible && account ? account : undefined);
        } catch (error) {
            console.error('Failed to get contract', error);
            return null;
        }
    }, [addressOrAddressMap, ABI, library, chainId, withSignerIfPossible, account]);
}


function ViewAavelope() {
    const contract = useContract('0x5eb3Bc0a489C5A8288765d2336659EbCA68FCd00', abi, true);
    const web3React = useWeb3React();
    const [svg, setSvg] = useState();
    const [unlockTimestamp, setUnlockTimestamp] = useState();
    const [currentAmount, setCurrentAmount] = useState();
    const [lockedAmount, setLockedAmount] = useState();
    console.log(contract);

    useEffect(() => {
        async function fetch() {
            const [svg, unlockTimestamp, currentAmount, lockedAmount] = await Promise.all([contract.getSvg(0), contract.getUnlockTimestamp(0), contract.getAmountAsOfNow(0), contract.getOriginalAmount(0)]);
            setSvg(svg);
            setUnlockTimestamp(unlockTimestamp);
            setCurrentAmount(currentAmount);
            setLockedAmount(lockedAmount);
        }

        if (contract) fetch();
    }, [contract]);

    if (!svg || !unlockTimestamp || !lockedAmount || !currentAmount) {
        return null;
    }
    return <VStack maxWidth={"80%"} flexDirection={"column"} alignItems={"center"} p={4} spacing={8}>
        {ReactHtmlParser(svg)}
        <VStack spacing={2}>
            <Heading size={"m"}>Owned by</Heading>
            <Text size={"m"}>{web3React.account}</Text>
        </VStack>
        <Box borderRadius={"xl"} border="1px" borderColor="gray.200" borderStyle={"solid"}><Table variant="simple" >
            <Tbody>
                <Tr>
                    <Td>Unlocked</Td>
                    <Td><Badge colorScheme="purple" p={1}>{DateTime.fromSeconds(unlockTimestamp.toNumber()).toRelative()}</Badge></Td>
                </Tr>
                <Tr>
                    <Td>Original amount</Td>
                    <Td><Badge colorScheme="green" p={1}>{Math.round(parseFloat(formatUnits(lockedAmount, 18))) } DAI</Badge> </Td>
                </Tr>
                <Tr>
                    <Td>Accrued amount</Td>
                    <Td><Badge colorScheme="green" p={1}>{Math.round(parseFloat(formatUnits(currentAmount, 18))) } DAI</Badge> </Td>
                </Tr>
                <Tr>
                    <Td>Amount at unlock (approx)</Td>
                    <Td><Badge colorScheme="green" p={1}>{Math.round(parseFloat(formatUnits(lockedAmount, 18)) * (1.02 * DateTime.fromSeconds(unlockTimestamp.toNumber()).diff(DateTime.now(), "years").as("years")))} DAI</Badge></Td>
                </Tr>
                <Tr>
                    <Td>Token Id</Td>
                    <Td>0</Td>
                </Tr>

            </Tbody>
        </Table></Box>


    </VStack>;
}

function Component() {
    const web3React = useWeb3React();

    return (<VStack spacing={8}>
        {!web3React.active && <Button onClick={async () => await web3React.activate(injected)}>{web3React.active ? 'Deactivate' : 'Act'}</Button>}
        {web3React.active && <ViewAavelope/>}
    </VStack>);
}

function App() {
    return (
        <Web3ReactProvider getLibrary={getLibrary}>
            <ChakraProvider>
                <Component/>
            </ChakraProvider>
        </Web3ReactProvider>
    );
}

export default App;
