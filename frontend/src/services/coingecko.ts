/**
 * CoinGecko API Service
 * Fetches cryptocurrency prices for TVL calculations
 */

const COINGECKO_API_KEY = import.meta.env.VITE_COINGECKO_API_KEY || 'CG-njMzeCqg4NmSv1JFwKypf5Zy'
const COINGECKO_API_URL = 'https://api.coingecko.com/api/v3'

interface CoinPrice {
  [coin: string]: {
    usd: number
    usd_market_cap?: number
    usd_24h_vol?: number
    usd_24h_change?: number
    last_updated_at?: number
  }
}

/**
 * Fetch prices for multiple coins
 * @param coinIds Array of CoinGecko coin IDs (e.g., ['ethereum', 'wrapped-bitcoin'])
 * @returns Object mapping coin IDs to their USD prices
 */
export async function getCoinPrices(coinIds: string[]): Promise<CoinPrice> {
  const ids = coinIds.join(',')
  const url = `${COINGECKO_API_URL}/simple/price?ids=${ids}&vs_currencies=usd&include_market_cap=false&include_24hr_vol=false&include_24hr_change=false`
  
  try {
    const response = await fetch(url, {
      method: 'GET',
      headers: {
        'x-cg-demo-api-key': COINGECKO_API_KEY,
      },
    })
    
    if (!response.ok) {
      throw new Error(`CoinGecko API error: ${response.status}`)
    }
    
    const data: CoinPrice = await response.json()
    return data
  } catch (error) {
    console.error('Error fetching coin prices from CoinGecko:', error)
    return {}
  }
}

/**
 * Get Ethereum price in USD
 */
export async function getEthereumPrice(): Promise<number> {
  const prices = await getCoinPrices(['ethereum'])
  return prices.ethereum?.usd || 0
}

/**
 * Get USDC price in USD (should always be ~$1)
 */
export async function getUSDCPrice(): Promise<number> {
  const prices = await getCoinPrices(['usd-coin'])
  return prices['usd-coin']?.usd || 1
}

/**
 * Calculate USD value from token amount and price
 */
export function calculateUSDValue(tokenAmount: number, priceUSD: number): number {
  return tokenAmount * priceUSD
}

/**
 * Format USD value for display
 */
export function formatUSDValue(value: number): string {
  if (value >= 1_000_000) {
    return `$${(value / 1_000_000).toFixed(2)}M`
  } else if (value >= 1_000) {
    return `$${(value / 1_000).toFixed(2)}K`
  } else {
    return `$${value.toFixed(2)}`
  }
}
