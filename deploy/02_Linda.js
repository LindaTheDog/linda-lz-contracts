module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const lzEndpoint = "0x1a44076050125825900e736c501f859c50fE728c";

  // the OFT standard token contract
  await deploy("Linda", {
    from: deployer,
    args: [lzEndpoint, deployer],
    log: true,
    deterministicDeployment: false,
  });
};

module.exports.tags = ["Linda"];
