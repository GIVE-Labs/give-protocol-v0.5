import StakeUSDC from '../components/staking/StakeUSDC';

export default function StakePage() {
  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-10">
      <div className="mb-6">
        <h1 className="text-3xl font-bold">Stake</h1>
        <p className="text-gray-600 mt-1">Deposit USDC on Sepolia to earn yield for verified NGOs.</p>
      </div>
      <StakeUSDC />
    </div>
  );
}

