# encoding: UTF-8
# frozen_string_literal: true

namespace :revert do
  desc "Revert user trade activity."
  task :trading_activity, [:member_email] => [:environment] do |_, args|

    member = Member.find_by(email: args[:member_email])

    member.trades.each do |t|
      seller_outcome = t.amount
      buyer_outcome = t.total

      seller_income = t.total - t.total * t.order_fee(t.sell_order)
      buyer_income = t.amount - t.amount * t.order_fee(t.buy_order)

      seller_fee = t.total * t.order_fee(t.sell_order)
      buyer_fee = t.amount * t.order_fee(t.buy_order)

      # Revert Trade for Sell side
      # Debit main fiat/crypto Liability account for member who created bid.
      Operations::Liability.debit!(
        amount: seller_income,
        currency: t.sell_order.income_currency,
        reference: t,
        kind: :main,
        member_id: t.sell_order.member_id
      )
      Account.find_by(currency_id: t.sell_order.income_currency.id, member_id: t.sell_order.member_id).sub_funds(seller_income)

      # Credit main fiat/crypto Liability account for member who created ask.
      Operations::Liability.credit!(
        amount: seller_outcome,
        currency: t.sell_order.outcome_currency,
        reference: t,
        kind: :main,
        member_id: t.sell_order.member_id
      )
      Account.find_by(currency_id: t.sell_order.outcome_currency.id, member_id: t.sell_order.member_id).plus_funds(seller_outcome)

      # Revert Trade for Buy side
      # Debit main fiat/crypto Liability account for member who created ask
      Operations::Liability.debit!(
        amount: buyer_income,
        currency: t.buy_order.income_currency,
        reference: t,
        kind: :main,
        member_id: t.buy_order.member_id
      )
      Account.find_by(currency_id: t.buy_order.income_currency.id, member_id: t.buy_order.member_id).sub_funds(buyer_income)

      # Credit main fiat/crypto Liability account for member who created bid.
      Operations::Liability.credit!(
        amount: buyer_outcome,
        currency: t.buy_order.outcome_currency,
        reference: t,
        kind: :main,
        member_id: t.buy_order.member_id
      )
      Account.find_by(currency_id: t.buy_order.outcome_currency.id, member_id: t.buy_order.member_id).plus_funds(buyer_outcome)

      # Revert Revenues
      Operations::Revenue.debit!(
        amount:    seller_fee,
        currency:  t.sell_order.income_currency,
        reference: t,
        member_id: t.sell_order.member_id
      )

      Operations::Revenue.debit!(
        amount:    buyer_fee,
        currency:  t.buy_order.income_currency,
        reference: t,
        member_id: t.buy_order.member_id
      )
    end
  end
end
