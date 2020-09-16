function getAfkHours(_afkHours) {
    return _afkHours.concat(Array(17).fill(0)).slice(0, 17);
}

module.exports = { getAfkHours: getAfkHours }
