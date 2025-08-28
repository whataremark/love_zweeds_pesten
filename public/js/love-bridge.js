(function(){
  window.LOVE_onState = window.LOVE_onState || function(state) {
    console.log('State update', state);
  };

  window.LOVE_onPlayers = window.LOVE_onPlayers || function(players) {
    console.log('Players update', players);
  };

  window.LOVE_onMove = window.LOVE_onMove || function(move) {
    console.log('Move', move);
  };

  window.LOVE_sendMove = function(payload) {
    if (window.NET && window.NET.playMove) {
      window.NET.playMove(payload);
    }
  };
})();
