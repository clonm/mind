new PublishEndpoint null, ->
  User.documents.find
    _id: @userId
  ,
    fields: User.EXTRA_PUBLISH_FIELDS()

new PublishEndpoint 'User.settings', ->
  User.documents.find
    _id: @userId
  ,
    fields:
      name: 1
      avatars: 1
      'services.facebook.id': 1
      'services.facebook.name': 1
      'services.facebook.link': 1
      'services.google.id': 1
      'services.google.name': 1
      'services.twitter.id': 1
      'services.twitter.screenName': 1
      researchData: 1
      delegations: 1

new PublishEndpoint 'User.profile', (userId) ->
  check userId, Match.DocumentId

  User.documents.find
    _id: userId
  ,
    fields: _.extend User.EXTRA_PUBLISH_FIELDS(),
      name: 1
      # Fields published by Meteor for logged-in users.
      username: 1
      emails: 1
      # We use profile field differently than how Meteor is using it.
      profile: 1

new PublishEndpoint 'User.autocomplete', (username, prefixSearch) ->
  check username, Match.Where (x) ->
    check x, Match.NonEmptyString
    # Based on Settings.USERNAME_REGEX.
    /^[A-Za-z0-9_]+$/.test x
  check prefixSearch, Boolean

  if prefixSearch
    @enableScope()

    User.documents.find
      username: new RegExp("^#{username}", 'i')
    ,
      fields:
        _id: 1
        name: 1
        username: 1
        avatar: 1
  else
    User.documents.find
      username: username
    ,
      fields:
        _id: 1
        name: 1
        username: 1
        avatar: 1

# TODO: Currently limited only to members. Generalize. Or should it be just users who can vote?
new PublishEndpoint 'User.list', (initialLimit) ->
  check initialLimit, Match.PositiveNumber

  @enableScope()

  getQuery = =>
    filter = @data('filter') or ''
    exceptIds = @data('exceptIds') or []
    check filter, String
    check exceptIds, [Match.DocumentId]

    # TODO: We should use proper full-text search and use filter as a string of keywords.
    filter = filter.trim()

    query =
      roles: 'member'
      _id:
        $nin: exceptIds

    if filter
      filter = Meteor._escapeRegExp filter

      _.extend query,
        $or: [
          username: new RegExp(filter, 'i')
        ,
          name: new RegExp(filter, 'i')
        ]

    query

  @autorun (computation) =>
    @setData 'count', User.documents.find(getQuery()).count()

  @autorun (computation) =>
    limit = @data('limit') or initialLimit
    check limit, Match.PositiveNumber

    User.documents.find getQuery(),
      fields: User.PUBLISH_FIELDS()
      limit: limit
      sort:
        # TODO: Sort by filter quality.
        username: 1
