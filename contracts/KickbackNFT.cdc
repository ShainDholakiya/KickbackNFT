

pub contract KickbackNFT: NonFungibleToken {

    pub var totalSupply: UInt64

    pub event ContractInitialized()
    pub event Withdraw(id: UInt64, from: Address?)
    pub event Deposit(id: UInt64, to: Address?)
    pub event Minted(id: UInt64, metadata: {String:String})

    pub let CollectionStoragePath: StoragePath
    pub let CollectionPublicPath: PublicPath
    pub let MinterStoragePath: StoragePath

    pub resource NFT: NonFungibleToken.INFT {
        pub let id: UInt64 
        pub let name: String
        pub let description: String
        pub let thumbnail: String

        pub let episodeID: String
        pub let podcastID: String
        pub let metadata: {String: String}

        init(
            id: UInt64,
            name: String,
            description: String,
            thumbnail: String,
            episodeID: String,
            podcastID: String,
            metadata: {String: String},
        ) {
            self.id = KickbackNFT.totalSupply
            KickbackNFT.totalSupply = KickbackNFT.totalSupply + 1
            self.name = name.concat(" #").concat(self.id.toString())
            self.description = description
            self.thumbnail = thumbnail
            
            self.episodeID = episodeID
            self.podcastID = podcastID
            self.metadata = metadata

            emit Minted(id: self.id, metadata: metadata)
        }

        pub fun getViews(): [Type] {
            return [
                Type<MetadataViews.Display>(),
                Type<MetadataViews.ExternalURL>(),
                Type<MetadataViews.NFTCollectionDisplay>(),
            ]
        }

        pub fun resolveView(_ view: Type): AnyStruct? {
            switch view {
                case Type<MetadataViews.Display>():
                    return MetadataViews.Display(
                        name: self.name,
                        description: self.description,
                        thumbnail: MetadataViews.HTTPFile(
                            url: self.thumbnail
                        )
                    )
                case Type<MetadataViews.ExternalURL>():
                    return MetadataViews.ExternalURL("https://open.kickback.fm/episode/nft/".concat(self.episodeID))
                case Type<MetadataViews.NFTCollectionDisplay>():
                    let media = MetadataViews.Media(
                        file: MetadataViews.HTTPFile(
                            url: "https://kickback-photos.s3.amazonaws.com/logo.svg"
                        ),
                        mediaType: "image/svg+xml"
                    )
                    return MetadataViews.NFTCollectionDisplay(
                        name: "Kickback Podcasts Episodes Collection",
                        description: "Welcome to the Kickback Episodes Collection! Collect free listener NFTs to unlock exclusive perks, content, and project allow lists.",
                        externalURL: MetadataViews.ExternalURL("https://open.kickback.fm"),
                        squareImage: MetadataViews.Media(
                                        file: MetadataViews.HTTPFile(
                                            url: "https://kickback-photos.s3.amazonaws.com/logo.png"
                                        ),
                                        mediaType: "image/png"
                                    ),
                        bannerImage: MetadataViews.Media(
                                        file: MetadataViews.HTTPFile(
                                            url: "https://kickback-photos.s3.amazonaws.com/banner.png"
                                        ),
                                         mediaType: "image/png"
                                    ),
                        socials: {
                            "twitter": MetadataViews.ExternalURL("https://twitter.com/viaKickback"),
                            "discord": MetadataViews.ExternalURL("https://discord.com/invite/5BrvrMxaJ2")
                        }
                    )
            }

            return nil
                
        }

    }

    pub resource interface KickbackNFTCollectionPublic {
        pub fun deposit(token: @NonFungibleToken.NFT)
        pub fun getIDs(): [UInt64]
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
        pub fun borrowViewResolver(id: UInt64): &KickbackNFT.NFT
        pub fun buy(collectionCapability: Capability<&Collection{KickbackNFT.KickbackNFTCollectionPublic}>, episodeID: String)
    }

    pub resource Collection: NonFungibleToken.Receiver, NonFungibleToken.Provider, NonFungibleToken.CollectionPublic, KickbackNFTCollectionPublic {
        // the id of the NFT --> the NFT with that id
        pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

        pub fun deposit(token: @NonFungibleToken.NFT) {
            let myToken <- token as! @KickbackNFT.NFT
            emit Deposit(id: myToken.id, to: self.owner?.address)
            self.ownedNFTs[myToken.id] <-! myToken
        }

        pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
            let token <- self.ownedNFTs.remove(key: withdrawID) ?? panic("This NFT does not exist")
            emit Withdraw(id: token.id, from: self.owner?.address)
            return <- token
        }

        pub fun getIDs(): [UInt64] {
            return self.ownedNFTs.keys
        }

        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
			return (&self.ownedNFTs[id] as &NonFungibleToken.NFT?)!
		}

        pub fun borrowViewResolver(id: UInt64): &KickbackNFT.NFT {
			let token = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
			let nft = token as! &NFT
			return nft as &KickbackNFT.NFT
		}

        pub fun buy(collectionCapability: Capability<&Collection{KickbackNFT.KickbackNFTCollectionPublic}>, episodeID: String) {
            pre {
				self.owner!.address == KickbackNFT.account.address : "You can only buy the NFT directly from the KickbackNFT account"
			}

            let kickbackCollection = KickbackNFT.account.getCapability(KickbackNFT.CollectionPublicPath)
                        .borrow<&AnyResource{KickbackNFT.KickbackNFTCollectionPublic}>()
                        ?? panic("Can't get the KickbackNFT collection.")
            let availableNFTs = kickbackCollection.getIDs()
            var availableID: UInt64
            for id in availableNFTs {
                let resolver = kickbackCollection.borrowViewResolver(id: id)
                if (resolver.episodeID == episodeID) {
                    availableID = id
                }
            }

            let receiver = collectionCapability.borrow() ?? panic("Could not borrow KickbackNFT collection")
            let token <- self.withdraw(withdrawID: availableID) as! @KickbackNFT.NFT

			receiver.deposit(token: <- token)
        }

        destroy() {
            destroy self.ownedNFTs
        }
    }

    pub fun createEmptyCollection(): @Collection {
        return <- create Collection()
    }

    pub resource NFTMinter {
        pub fun mintNFT(
            name: String, description: String, thumbnail: String, episodeID: String, podcastID: String, metadata: {String: String}
        ) {
            let accountOwnerCollection = KickbackNFT.account.borrow<&AnyResource{NonFungibleToken.CollectionPublic}>(from: KickbackNFT.CollectionStoragePath)!
            accountOwnerCollection.deposit(token: <-create KickbackNFT.NFT(name: name, description: description, thumbnail: thumbnail, episodeID: episodeID, podcastID: podcastID, metadata: metadata))
        }
    }

    init() {
        self.totalSupply = 0

        self.CollectionStoragePath = /storage/EpisodeNFTCollection
        self.CollectionPublicPath = /public/EpisodeNFTCollection
        self.MinterStoragePath = /storage/EpisodeNFTMinter

        let minter <- create NFTMinter()
        self.account.save(<-minter, to: self.MinterStoragePath)

        emit ContractInitialized()
    }

}