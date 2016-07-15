function getQueryString(field, url) {
    const href = url ? url : window.location.href;
    const reg = new RegExp( '[?&]' + field + '=([^&#]*)', 'i' );
    const string = reg.exec(href);
    return string ? string[1] : "";
}

function getChannelSuffix() {
    const fromURL = getQueryString("suffix");
    return (fromURL === "") ? "" : ("-" + fromURL);
}

export default {
    getQueryString: getQueryString,
    getChannelSuffix: getChannelSuffix
}