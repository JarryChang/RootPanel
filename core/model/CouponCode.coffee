{utils, config} = app
{_, ObjectId, mongoose, mongooseUniqueValidator} = app.libs

CouponCode = mongoose.Schema
  code:
    required: true
    unique: true
    type: String

  expired:
    type: Date

  available_times:
    type: Number

  type:
    required: true
    type: String
    enum: ['amount']

  meta:
    type: Object

  apply_log: [
    account_id:
      required: true
      type: ObjectId
      ref: 'Account'

    created_at:
      type: Date
      default: Date.now
  ]

CouponCode.plugin mongooseUniqueValidator,
  message: 'unique_validation_error'

config.coupons_meta = coupons_meta =
  amount:
    validate: (account, coupon, callback) ->
      apply_log = _.find coupon.apply_log, (item) ->
        return item.account_id.toString() == account._id.toString()

      if apply_log
        return callback()

      coupon.constructor.findOne
        type: 'amount'
        'meta.category': coupon.meta.category
        'apply_log.account_id': account._id
      , (err, result) ->
        callback not result

    message: (req, coupon, callback) ->
      callback req.t 'coupons.amount.message',
        amount: coupon.meta.amount
        currency: req.t "plan.currency.#{config.billing.currency}"

    apply: (account, coupon, callback) ->
      account.incBalance coupon.meta.amount, 'deposit',
        type: 'coupon'
        order_id: coupon.code
      , callback

# @param template: [expired], available_times, type, meta
# @param callback(err, coupons)
CouponCode.statics.createCodes = (template, count, callback) ->
  coupons = _.map _.range(0, count), ->
    return {
      code: utils.randomString 16
      expired: template.expired or null
      available_times: template.available_times
      type: template.type
      meta: template.meta
      apply_log: []
    }

  @create coupons, callback

CouponCode.methods.getMessage = (req, callback) ->
  coupons_meta[@type].message req, @, callback

# @param callback(is_available)
CouponCode.methods.validateCode = (account, callback) ->
  if @available_times <= 0
    return callback()

  coupons_meta[@type].validate account, @, callback

CouponCode.methods.applyCode = (account, callback) ->
  if @available_times <= 0
    return callback true

  @update
    $inc:
      available_times: -1
    $push:
      apply_log:
        account_id: account._id
        created_at: new Date()
  , (err) =>
    return callback err if err
    coupons_meta[@type].apply account, @, callback

_.extend app.models,
  CouponCode: mongoose.model 'CouponCode', CouponCode
