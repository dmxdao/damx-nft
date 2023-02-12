const { getMessage } = require('eip-712')
const { ecsign } = require('ethereumjs-util')

function getSign(typedData, privateKey) {
  const message = getMessage(typedData, true)
  const { r, s, v } = ecsign(message, Buffer.from(privateKey, 'hex'))

  return {r, s, v}
}

module.exports = {
  getSign
}
