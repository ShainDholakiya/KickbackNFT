import NonFungibleToken from "../contracts/NonFungibleToken.cdc"
import KickbackNFT from "../contracts/KickbackNFT.cdc"

pub fun main(account: Address): [&KickbackNFT.NFT?] {
    let collection = getAccount(account).getCapability(KickbackNFT.CollectionPublicPath)
                        .borrow<&AnyResource{NonFungibleToken.CollectionPublic, KickbackNFT.KickbackNFTCollectionPublic}>()
                        ?? panic("Can't get the User's collection.")
    let answer: [&KickbackNFT.NFT?] = []
    let ids = collection.getIDs()
    for id in ids {
        let resolver = collection.borrowViewResolver(id: id)
        answer.append(resolver)
    }
    return answer
}