module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const lindaToken = "0x82cC61354d78b846016b559e3cCD766fa7E793D5"; // LINDA erc20 token on Linea Mainnet
  const localEndpointAddr = "0x1a44076050125825900e736c501f859c50fe728c";

  console.log(`Deployer address is: ${deployer}`);
  console.log(`Now deploying...`);

  await deploy("LindaOmniBridge", {
    from: deployer,
    args: [lindaToken, localEndpointAddr, deployer],
    log: true,
    deterministicDeployment: false,
  });
};

module.exports.tags = ["LindaOmniBridge"];
