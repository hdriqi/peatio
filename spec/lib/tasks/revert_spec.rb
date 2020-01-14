# frozen_string_literal: true

Rails.application.load_tasks

def run_task(task_name:)
  Rake::Task[task_name].invoke
end

describe 'revert.rake' do
  let(:bob) { create(:member, :level_3, email: 'bob@gmail.com') }
  let(:alice) { create(:member, :level_3, email: 'alice@gmail.com') }

  subject { Rake::Task['revert:trading_activity'] }

  after(:each) { subject.reenable }

  context 'simple case' do
    let(:price)  { 10.to_d }
    let(:volume) { 5.to_d }
    let(:ask) { ::Matching::LimitOrder.new create(:order_ask, :btcusd, price: price, volume: volume, member: alice).to_matching_attributes }
    let(:bid) { ::Matching::LimitOrder.new create(:order_bid, :btcusd, price: price, volume: volume, member: bob).to_matching_attributes }

    let(:executor) do
      Matching::Executor.new(
        action: 'execute',
        trade: {
          market_id: 'btcusd',
          maker_order_id: ask.id,
          taker_order_id: bid.id,
          strike_price: price.to_s('F'),
          amount: volume.to_s('F'),
          total: (price * volume).to_s('F')
        }
      )
    end

    before do
      # Plus 5 btc to Alice
      # Plus 50 usd to Bob
      alice.accounts.find_by(currency_id: :btc).plus_funds(5)
      bob.accounts.find_by(currency_id: :usd).plus_funds(50)
      alice.accounts.find_by(currency_id: :btc).lock_funds(5)
      bob.accounts.find_by(currency_id: :usd).lock_funds(50)
      executor.execute!
    end

    it 'revert trading activities' do
      subject.invoke(bob.email)
      expect(alice.accounts.find_by(currency_id: :btc).balance).to eq(5)
      expect(bob.accounts.find_by(currency_id: :usd).balance).to eq(50)
      expect(Operations.validate_accounting_equation(Operations::Liability.all +
        Operations::Asset.all +
        Operations::Revenue.all +
        Operations::Expense.all)).to eq(true)
    end
  end

  context 'several trades' do
    let(:price) { 10.to_d }
    let(:volume) { 5.to_d }
    let(:volume1) { 3.to_d }
    let(:volume2) { 2.to_d }
    let(:ask) { ::Matching::LimitOrder.new create(:order_ask, :btcusd, price: price, volume: volume, member: alice).to_matching_attributes }
    let(:bid) { ::Matching::LimitOrder.new create(:order_bid, :btcusd, price: price, volume: volume1, member: bob).to_matching_attributes }
    let(:bid1) { ::Matching::LimitOrder.new create(:order_bid, :btcusd, price: price, volume: volume2, member: bob).to_matching_attributes }

    let(:executor1) do
      Matching::Executor.new(
        action: 'execute',
        trade: {
          market_id: 'btcusd',
          maker_order_id: ask.id,
          taker_order_id: bid.id,
          strike_price: price.to_s('F'),
          amount: volume1.to_s('F'),
          total: (price * volume1).to_s('F')
        }
      )
    end

    let(:executor2) do
      Matching::Executor.new(
        action: 'execute',
        trade: {
          market_id: 'btcusd',
          maker_order_id: ask.id,
          taker_order_id: bid1.id,
          strike_price: price.to_s('F'),
          amount: volume2.to_s('F'),
          total: (price * volume2).to_s('F')
        }
      )
    end

    before do
      # Plus 5 btc to Alice
      # Plus 50 usd to Bob
      alice.accounts.find_by(currency_id: :btc).plus_funds(5)
      bob.accounts.find_by(currency_id: :usd).plus_funds(50)
      alice.accounts.find_by(currency_id: :btc).lock_funds(5)
      bob.accounts.find_by(currency_id: :usd).lock_funds(50)
      executor1.execute!
      executor2.execute!
    end

    it 'reverts trading activities' do
      subject.invoke(bob.email)
      expect(alice.accounts.find_by(currency_id: :btc).balance).to eq(5)
      expect(bob.accounts.find_by(currency_id: :usd).balance).to eq(50)
      expect(Operations.validate_accounting_equation(Operations::Liability.all +
             Operations::Asset.all +
             Operations::Revenue.all +
             Operations::Expense.all)).to eq(true)
    end
  end
end
