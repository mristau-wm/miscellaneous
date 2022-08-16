# The Result and CpcDefundService classes can be used in console
# to defund all campaigns and organizations for a given set of region IDs
# This is based on https://github.com/GhostGroup/weedmaps/blob/cpc-rollback/cpc_rollback.rb

# Example usage:

# or_region_ids = [385,386,574,575,2267]
# nm_region_ids = [588,2399,3558,3524,609,608,680,607,589,1555,681,1331,3557]

# service = CpcDefundService.new(or_region_ids, dry_run: false)
# service.call
# service.print_results

# service = CpcDefundService.new(nm_region_ids, dry_run: false)
# service.call
# service.print_results

# Results: https://docs.google.com/spreadsheets/d/1QTgw9sTmVd08acmjq9WxJAE0B79NajF3MzP9EV8J-ss

class Result < Hashie::Mash
  def valid?
    self.errors ||= []
    unless [organization, campaign, flight].all?(&:present?)
      errors << 'Missing one or more required objects'
      return false
    end
    true
  end
end

# Service algorithm:
#   for each region ID
#     get all campaigns in region
#     group campaigns by organization
#     for each organization
#       defund campaigns
#       defund organization
class CpcDefundService
  attr_accessor :region_ids, :dry_run, :campaign_results, :organization_results

  def initialize(region_ids, dry_run: true)
    self.region_ids = region_ids
    self.dry_run = dry_run
    self.campaign_results = []
    self.organization_results = []
    @current_region_id = nil
  end

  def print_results
    csv = headers.to_csv
    campaign_results.each { |result| csv += result_csv(result) }
    puts csv
    nil
  end

  def call
    puts "Cpc Defund service invoked. Dry run: #{dry_run}"

    region_ids.each do |region_id|
      @current_region_id = region_id
      puts "Processing region: #{region_id}"
      campaigns = Advertising::Campaign.where(region_id: region_id)

      campaigns_by_org_id(campaigns).each do |org_id, campaigns|
        puts "Processing organization: '#{org_id}'"

        campaigns.each do |campaign|
          campaign_results << process_funds_for(campaign)
        end

        organization_results << process_funds_for_org(org_id)
      end
    end
  end

  def campaigns_by_org_id(campaigns)
    campaigns_by_org_id = {}

    campaigns.each do |campaign|
      org_id = campaign.listing.advertising_organization.id

      if campaigns_by_org_id.has_key?(org_id)
        campaigns_by_org_id[org_id] << campaign
      else
        campaigns_by_org_id[org_id] = [campaign]
      end
    end

    campaigns_by_org_id
  end

  def process_funds_for(campaign) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
    print "Processing campaign #{campaign.id}, dry_run: #{dry_run}"

    Result.new.tap do |result|
      result.plutii = []
      result.campaign = campaign
      result.flight = result.campaign.flight
      result.listing = result.flight.listing
      result.organization = result.listing&.advertising_organization
      result.credit_due = result.flight.cash_account.balance
      result.promo_canceled = result.flight.monthly_promo_account.balance

      if result.valid?
        result.plutii << salesforce_credit_for(result) if result.credit_due.positive?
        result.plutii << cancel_promo_for(result) if result.promo_canceled.positive?
        puts ', valid'
      else
        puts ", invalid: #{result.errors.to_sentence}"
      end
    end
  end

  def salesforce_credit_for(result)
    output = { from: result.flight.cash_account.name,
               to: 'weedmaps_cash',
               amount: result.credit_due,
               description: "Region #{result.campaign.region_id} deactivation – returned to client" }

    if dry_run
      output
    else
      entry = create_entry result.flight.cash_account, weedmaps_cash, output[:amount], output[:description]
      output.merge id: entry.id
    end
  end

  def cancel_promo_for(result)
    output = { from: result.flight.monthly_promo_account.name,
               to: 'weedmaps_promo',
               amount: result.promo_canceled,
               description: "Region #{result.campaign.region_id} deactivation – promo canceled" }

    if dry_run
      output
    else
      entry = create_entry result.flight.monthly_promo_account, weedmaps_promo, output[:amount], output[:description]
      output.merge id: entry.id
    end
  end

  def process_funds_for_org(org_id)
    org = Organization.find(org_id)
    credit_due = 0
    promo_canceled = 0
    plutii = []

    # salesforce credit
    if org.cash_account.balance.positive?
      credit_due = org.cash_account.balance
      output = { from: org.cash_account.name,
                 to: 'weedmaps_cash',
                 amount: credit_due,
                 description: "Region #{@current_region_id} deactivation – returned to client" }

      if dry_run
        output
      else
        entry = create_entry org.cash_account, weedmaps_cash, output[:amount], output[:description]
        output.merge id: entry.id
      end

      plutii << output
    end

    # promo cancellation
    if org.monthly_promo_account.balance.positive?
      promo_canceled = org.monthly_promo_account.balance
      output = { from: org.monthly_promo_account.name,
                 to: 'weedmaps_promo',
                 amount: promo_canceled,
                 description: "Region #{@current_region_id} deactivation – promo canceled" }

      if dry_run
        output
      else
        entry = create_entry org.monthly_promo_account, weedmaps_promo, output[:amount], output[:description]
        output.merge id: entry.id
      end

      plutii << output
    end

    # print and return summary of results for org
    results = [org.id,org.salesforce_id,@current_region_id,credit_due,promo_canceled,plutii].to_csv
    puts "Org results: #{results}"
    results
  end

  def headers
    [
      'Core organization ID',
      'Core campaign ID',
      'Core flight ID',
      'Salesforce ID',
      'Credit due',
      'Promo canceled',
      'Errors',
      'Plutus entries'
    ]
  end

  def result_csv(result)
    [
      result.organization&.id,
      result.campaign&.id,
      result.flight&.id,
      result.organization&.salesforce_id,
      result.credit_due,
      result.promo_canceled,
      result.errors.to_sentence,
      result.plutii
    ].to_csv
  end

  def create_entry(from, to, amount, description)
    Plutus::Entry.new(description: description).tap do |entry|
      entry.debits = [{ account: from, amount: amount }]
      entry.credits = [{ account: to, amount: amount }]
      entry.save!
    end
  end

  def weedmaps_cash
    @weedmaps_cash ||= Advertising::Accounts.cash
  end

  def weedmaps_promo
    @weedmaps_promo ||= Advertising::Accounts.monthly_promo
  end
end

