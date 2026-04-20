import QtQuick
pragma Singleton

QtObject {
    property bool isOpen: false
    property bool isThinking: false
    property string currentModel: "qwen"
    property string chatHistory: ""

    function toggle() {
        isOpen = !isOpen;
    }

    function ask(prompt) {
        if (!prompt || isThinking)
            return ;

        chatHistory += "👤 **Du:** " + prompt + "\n\n";
        isThinking = true;
        var http = new XMLHttpRequest();
        var url = "http://localhost:11434/api/generate";
        var params = JSON.stringify({
            "model": currentModel,
            "prompt": prompt,
            "stream": false
        });
        http.open("POST", url, true);
        http.setRequestHeader("Content-type", "application/json");
        http.onreadystatechange = function() {
            if (http.readyState === 4) {
                isThinking = false;
                if (http.status === 200) {
                    var response = JSON.parse(http.responseText);
                    chatHistory += "🤖 **AI:** " + response.response + "\n\n";
                } else {
                    chatHistory += "❌ *Fehler: Verbindung fehlgeschlagen.*\n\n";
                }
            }
        };
        http.send(params);
    }

}
