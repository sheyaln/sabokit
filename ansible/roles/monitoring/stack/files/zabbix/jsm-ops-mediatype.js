var method,
    Media = {
    params: {},
    name: '',
    labels: [],
    HTTPProxy: '',

    setParams: function (params) {
        if (typeof params !== 'object') {
            return;
        }

        Media.params = params;

        // Ensure base URLs end with a slash for simple concatenation.
        Media.params.api += Media.params.api.endsWith('/') ? '' : '/';
        Media.params.web += Media.params.web.endsWith('/') ? '' : '/';
    },

    setProxy: function (HTTPProxy) {
        if (typeof HTTPProxy !== 'undefined' && HTTPProxy.trim() !== '') {
            Media.HTTPProxy = HTTPProxy;
        }
    },

    setTags: function (event_tags_json) {
        if (typeof event_tags_json !== 'undefined' && event_tags_json !== ''
                && event_tags_json !== '{EVENT.TAGSJSON}') {

            try {
                var tags = JSON.parse(event_tags_json),
                    label;

                tags.forEach(function (tag) {
                    if (typeof tag.tag === 'string') {
                        label = (tag.tag + (typeof tag.value !== 'undefined'
                                && tag.value !== '' ? (':' + tag.value) : '')).replace(/\s/g, '_');
                        Media.labels.push(label);
                    }
                });
            }
            catch (error) {
                Zabbix.log(4, '[ ' + Media.name + ' Webhook ] Failed to parse "event_tags_json" param');
            }
        }
    },

    request: function (method, query, data, allow_404) {
        if (typeof(allow_404) === 'undefined') {
            allow_404 = false;
        }

        ['api', 'token'].forEach(function (field) {
            if (typeof Media.params !== 'object' || typeof Media.params[field] === 'undefined'
                    || Media.params[field] === '') {
                throw 'Required ' + Media.name + ' param is not set: "' + field + '".';
            }
        });

        var response,
            url = Media.params.api + query,
            request = new HttpRequest();

        request.addHeader('Content-Type: application/json');
        request.addHeader('Authorization: ' + Media.params.token);
        request.setProxy(Media.HTTPProxy);

        if (typeof data !== 'undefined') {
            data = JSON.stringify(data);
        }

        Zabbix.log(4, '[ ' + Media.name + ' Webhook ] Sending request: ' +
            url + ((typeof data === 'string') ? ('\n' + data) : ''));

        switch (method) {
            case 'get':
                response = request.get(url, data);
                break;

            case 'post':
                response = request.post(url, data);
                break;

            case 'put':
                response = request.put(url, data);
                break;

            default:
                throw 'Unsupported HTTP request method: ' + method;
        }

        Zabbix.log(4, '[ ' + Media.name + ' Webhook ] Received response with status code ' +
            request.getStatus() + '\n' + response);

        if (response !== null) {
            try {
                response = JSON.parse(response);
            }
            catch (error) {
                Zabbix.log(4, '[ ' + Media.name + ' Webhook ] Failed to parse response.');
                response = null;
            }
        }

        if ((request.getStatus() < 200 || request.getStatus() >= 300)
                && (!allow_404 || request.getStatus() !== 404)) {
            var message = 'Request failed with status code ' + request.getStatus();

            if (response !== null) {
                if (typeof response.errors === 'object' && Object.keys(response.errors).length > 0) {
                    message += ': ' + JSON.stringify(response.errors);
                }
                else if (typeof response.errorMessages === 'object'
                        && Object.keys(response.errorMessages).length > 0) {
                    message += ': ' + JSON.stringify(response.errorMessages);
                }
                else if (typeof response.message === 'string') {
                    message += ': ' + response.message;
                }
            }

            throw message + ' Check debug log for more information.';
        }

        return {
            status: request.getStatus(),
            response: response
        };
    },

    // Poll Integration Events API until the alert is actually created
    // so we can grab alertId for linking.
    getAlertId: function (requestId) {
        var status_counter = params.status_counter || 25,
            resp;

        do {
            resp = Media.request('get', 'requests/' + requestId, undefined, true);
            status_counter -= 1;
        }
        while (
            status_counter > 0 &&
            (
                typeof resp.response !== 'object' ||
                typeof resp.response.data === 'undefined' ||
                (
                    resp.response.data.success === false &&
                    !resp.response.data.status.includes('There is no open alert') &&
                    !resp.response.data.status.includes('Alert is already')
                )
            )
        );

        if (typeof resp.response !== 'object' || typeof resp.response.data === 'undefined') {
            throw 'Cannot get ' + Media.name + ' alert ID. Check debug log for more information.';
        }
        else if (resp.response.data.success === false) {
            throw Media.name + ': Operation status (' + resp.response.data.status + ')';
        }

        return resp;
    }
};

try {
    var result = {tags: {}},
        params = JSON.parse(value),
        media = {},
        fields = {},
        resp = {},
        responders = [],
        tags = [],
        required_params = [
            'alert_subject',
            'alert_message',
            'event_id',
            'event_source',
            'event_value',
            'event_update_status',
            'jsmops_api',
            'jsmops_web',
            'jsmops_token'
        ],
        severities = [
            'not_classified',
            'information',
            'warning',
            'average',
            'high',
            'disaster',
            'resolved',
            'default'
        ],
        priority;

    Object.keys(params).forEach(function (key) {
        if (required_params.indexOf(key) !== -1 && params[key].trim() === '') {
            throw 'Parameter "' + key + '" cannot be empty.';
        }

        // Pick up all params starting with jsmops_ and move into Media.params
        if (key.startsWith('jsmops_')) {
            media[key.substring(7)] = params[key];
        }
    });

    // Validate event_source: 0 Trigger, 1 Discovery, 2 Autoreg, 3 Internal
    if ([0, 1, 2, 3].indexOf(parseInt(params.event_source)) === -1) {
        throw 'Incorrect "event_source" parameter given: "' + params.event_source + '". Must be 0-3.';
    }

    // Validate event_value for trigger/internal: 0 = recover, 1 = problem
    if (params.event_value !== '0' && params.event_value !== '1'
        && (params.event_source === '0' || params.event_source === '3')) {
        throw 'Incorrect "event_value" parameter given: ' + params.event_value + '. Must be 0 or 1.';
    }

    // Validate event_update_status for trigger-based events.
    // 0 = problem/recovery event, 1 = update operation.
    if (params.event_source === '0' && params.event_update_status !== '0'
            && params.event_update_status !== '1') {
        throw 'Incorrect "event_update_status" parameter given: ' +
            params.event_update_status + '. Must be 0 or 1.';
    }

    // event_id must be positive number
    if (isNaN(parseInt(params.event_id)) || params.event_id < 1) {
        throw 'Incorrect "event_id" parameter given: ' + params.event_id + '. Must be a positive number.';
    }

    // Discovery/autoregistration recoveries not supported
    if ((params.event_source === '1' || params.event_source === '2') && params.event_value === '0') {
        throw 'Recovery operations are supported only for Trigger and Internal actions.';
    }

    if ([0, 1, 2, 3, 4, 5].indexOf(parseInt(params.event_nseverity)) === -1) {
        params.event_nseverity = '7'; // default
    }

    if (params.event_value === '0') {
        params.event_nseverity = '6'; // resolved
    }

    priority = params['severity_' + severities[params.event_nseverity]];

    params.zbxurl = params.zbxurl + (params.zbxurl.endsWith('/') ? '' : '/');

    Media.name = 'JSM Ops';
    Media.setParams(media);

    // JSM Ops Integration Events API uses GenieKey <apiKey> header
    Media.params.token = 'GenieKey ' + Media.params.token;

    Media.setProxy(params.HTTPProxy);
    Media.setTags(params.event_tags_json); // fill Media.labels

    // CREATE ALERT:
    // event_source 0 or 3, event_value 1, update_status 0, or discovery/autoreg events.
    if ((params.event_source == 0 && params.event_value == 1 && params.event_update_status == 0)
            || (params.event_source == 3 && params.event_value == 1)
            || params.event_source == 1
            || params.event_source == 2) {

        fields.message     = params.alert_subject;
        fields.alias       = params.event_id;
        fields.description = params.alert_message;
        fields.priority    = priority;
        fields.source      = 'Zabbix';

        if (params.event_source === '0') {
            fields.details = {
                'Zabbix server': params.zbxurl,
                'Problem': params.zbxurl + 'tr_events.php?triggerid=' +
                    params.trigger_id + '&eventid=' + params.event_id
            };
        }
        else {
            fields.details = {'Zabbix server': params.zbxurl};
        }

        if (typeof params.jsmops_teams === 'string') {
            responders = params.jsmops_teams.split(',');
            fields.responders = responders.map(function (team) {
                return {type: 'team', name: team.trim()};
            });
        }

        fields.tags = Media.labels;

        if (typeof params.jsmops_tags === 'string') {
            tags = params.jsmops_tags.split(',');
            tags.forEach(function (item) {
                fields.tags.push(item.trim());
            });
        }

        // POST /jsm/ops/integration/v2/alerts
        resp = Media.request('post', '', fields);

        if (typeof resp.response !== 'object' || typeof resp.response.result === 'undefined') {
            throw 'Cannot create ' + Media.name + ' alert. Check debug log for more information.';
        }

        if (resp.status === 202) {
            // Poll requests/{requestId} to get alertId (same pattern as Opsgenie Integration API).
            resp = Media.getAlertId(resp.response.requestId);

            if (params.event_source == 0 && params.event_value == 1 && params.event_update_status == 0) {
                // Store alert ID & link back to JSM Ops in Zabbix tags.
                result.tags.__zbx_ops_issuekey  = resp.response.data.alertId;
                result.tags.__zbx_ops_issuelink = Media.params.web + 'alert/detail/' +
                                                  resp.response.data.alertId;
            }
        }
        else {
            throw Media.name + ' response code is unexpected. Check debug log for more information.';
        }
    }
    // UPDATE / CLOSE ALERT:
    else {
        fields.user  = (params.event_value != 0) ? params.zbxuser : '';
        fields.note  = params.alert_message;
        fields.source = 'Zabbix';

        // Decide which JSM Ops action we're calling.
        if ([0, 3].indexOf(parseInt(params.event_source)) > -1 && params.event_value == 0) {
            // Close only once; skip duplicate recovery from update operations
            method = (params.event_update_status == 0) ? 'close' : 'skip';
        }
        else if (params.event_source == 0 && params.event_value == 1 &&
                 params.event_update_status == 1 &&
                 params.event_update_action && params.event_update_action.includes('acknowledged')) {

            method = params.event_update_action.includes('unacknowledged')
                ? 'unacknowledge'
                : 'acknowledge';
        }
        else {
            method = 'notes';
        }

        if (method !== 'skip') {
            // POST /jsm/ops/integration/v2/alerts/{id}/{method}?identifierType=alias
            resp = Media.request(
                'post',
                params.event_id + '/' + method + '?identifierType=alias',
                fields
            );

            if (typeof resp.response !== 'object' || typeof resp.response.result === 'undefined') {
                throw 'Cannot update ' + Media.name + ' alert. Check debug log for more information.';
            }

            if (resp.status === 202) {
                resp = Media.getAlertId(resp.response.requestId);
            }
            else {
                throw Media.name + ' response code is unexpected. Check debug log for more information.';
            }
        }
    }

    return JSON.stringify(result);
}
catch (error) {
    Zabbix.log(3, '[ ' + Media.name + ' Webhook ] ERROR: ' + error);
    throw 'Sending failed: ' + error;
}



