const { sendTxn, deployContract } = require("./utils/helpers");

const communityFund = process.env.COMMUNITY_FUND;
const esDmx = process.env.ES_DMX;
const dmxVester = process.env.DMX_VESTER;
const usdcAddr = process.env.USDC_ADDR;

// The main deployment script
const main = async () => {
    const rewardToken = usdcAddr;
    const time = parseInt(new Date().getTime() / 1000, 10);
    const epochLength = 3600 * 1; // 1 hour for test
    const epochReward = 1000_000_000 // 1000 USDC

    const robotSale = await deployContract("RobotSale", [communityFund, esDmx, dmxVester, usdcAddr]);
    const nftAddr = await robotSale.damxRobot();
    const staking = await deployContract("DamxRobotStaking", [nftAddr, rewardToken, time, epochLength, epochReward]);
    const distributor =  await deployContract("EpochRewardDistributor", [staking.address]);

    // initialize staking
    await sendTxn(staking.initialize(distributor.address), `DamxRobotStaking.initialize(${distributor.address})`);
}
// Runs the deployment script, catching any errors
main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
  });