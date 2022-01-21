# KBOA issue was that kevel budget became greater than core budget.
# Now that we've fixed the app to prevent this from happening,
# we want to monitor to alert if it happens again.
# But first we want to resolve existing discrepancies.
# 
# So, for campaigns with kevel budget greater than core budget,
# we want to sync them. We'll credit the campaign with the difference.
#
# Results: https://docs.google.com/spreadsheets/d/1VYnhB7cmtPCzypaXOjO42zA-MRVOarI1vdcVFMRDvog/edit#gid=606809187

class Corrector
  attr_accessor :rows, :entries
  KEYS = %i[campaign_id adzerk_campaign_id adzerk_flight_id credit wmid org_id org_sf_id core_remaining_budget core_balance kevel_lifetime_cap kevel_revenue kevel_balance entries notes]

  def initialize
    self.rows = []
    self.entries = []
  end

  def print_headers
    puts KEYS.join('|')
  end

  def print_row(row)
    row[:notes] = row[:notes].join(",") if row[:notes].is_a? Array
    if row[:entries].is_a? Array
      row[:entries] = row[:entries].map(&:to_s)
      row[:entries] = row[:entries].join(",")
    end
    puts KEYS.map{|k| row[k]}.join('|')
  end

  def print_rows
    print_headers
    rows.each {|row| print_row row }
    nil
  end

  def create_entry(from, to, amount, description)
    Plutus::Entry.new(description: description).tap do |entry|
      entry.debits = [{ account: from, amount: amount }]
      entry.credits = [{ account: to, amount: amount }]
      entry.save!
    end
  end

  def grant
    grants.each do |flight, cents, core_balance, kevel_balance|
      campaign = flight.campaign
      org = campaign.listing.advertising_organization
      credit = cents

      puts "processing #{flight.adzerk_id}"

      row = {}
      row[:entries] = []
      row[:notes] = []
      row[:campaign_id] = campaign.id
      row[:adzerk_campaign_id] = campaign.adzerk_id
      row[:adzerk_flight_id] = flight.adzerk_id
      row[:core_remaining_budget] = flight.remaining_budget
      row[:core_balance] = core_balance
      row[:kevel_balance] = kevel_balance
      row[:credit] = credit
      row[:wmid] = campaign.wmid
      row[:org_id] = org.id
      row[:org_sf_id] = org.salesforce_id
      row[:kevel_lifetime_cap] = flight.lifetime_cap
      row[:kevel_revenue] = flight.revenue_from_deltas

      Advertising::CampaignSettlementResult.transaction do
        # transfer into organization out of money printer
        entry = create_entry \
          Advertising::Accounts.cash_correction,
          org.cash_account,
          credit,
          'advertising.kboa_correction.cash_credit'
        row[:entries] << entry.inspect
        row[:notes] << ["successfully added cash_spent to org"]

        # transfer into campaign and out of organization
        transfer_args = {
          organization_id: org.id,
          debit_entity: org,
          credit_entity: flight,
          user_id: nil,
          price_value: credit.floor,
          entry_description: 'advertising.cor9294.cash_credit'
        }
        result = Advertising::TransferService::Cash.call transfer_args
        # result = OpenStruct.new success?: true

        if result.success?
          row[:notes] << ["successful transfer #{transfer_args}"]
        else
          row[:notes] << ["failed transfer #{transfer_args}"]
        end
      end
      self.rows << row
    end
  end

  def grants
    @grants ||= [].tap do |grants|
      Advertising::Flight.includes(:campaign).find_each do |flight|
        # Working strictly in cents here
        core_balance = flight.balance
        kevel_balance = flight.lifetime_cap - flight.revenue_from_deltas

        next if kevel_balance <= core_balance
        next if flight.lifetime_cap.zero?

        grants << [flight, kevel_balance - core_balance, core_balance, kevel_balance]
      end
    end
  end
end
